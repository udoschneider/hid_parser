defmodule HidParser.ReportCodec do
  @moduledoc """
  The compiled report model: a codec that decodes and encodes HID reports.

  `compile/2` turns a parsed `HidParser.ReportDescriptor` tree into this flat
  field model — resolving global/local item state, `Push`/`Pop`, collection
  nesting, report IDs and usage inheritance. `decode/2` then turns report bytes
  into a `HidParser.Report`, and `encode/2` turns it back:

      {:ok, descriptor} = HidParser.ReportDescriptor.parse(descriptor_bytes)
      {:ok, codec}      = HidParser.ReportCodec.compile(descriptor, vid: vid, pid: pid)
      {:ok, report}     = HidParser.ReportCodec.decode(codec, report_bytes)
      {:ok, binary}     = HidParser.ReportCodec.encode(codec, report)

  ## Bit packing

  Fields are packed LSB-first in field order; a count-N field contributes N
  consecutive values of `size` bits each. A report that uses report IDs prefixes
  the id byte to every report. Constant fields are descriptor-driven: they are
  skipped by `decode/2` and packed as zero bits by `encode/2`.
  """

  import Bitwise

  alias HidParser.Error
  alias HidParser.Report
  alias HidParser.Report.Value
  alias HidParser.ReportCodec.Field
  alias HidParser.ReportDescriptor
  alias HidParser.ReportDescriptor.Helper

  alias HidParser.ReportDescriptor.{Collection, Feature, Input, Output, Pop, Push}

  @type t :: %__MODULE__{
          vid: integer() | nil,
          pid: integer() | nil,
          reports: %{optional(integer()) => [Field.t()]},
          uses_report_id?: boolean()
        }

  defstruct vid: nil, pid: nil, reports: %{}, uses_report_id?: false

  # === Compile ==============================================================

  @doc """
  Compiles a parsed report descriptor tree into a `t:t/0`.

  Options:

    * `:vid`, `:pid` — device metadata stored verbatim on the codec.

  Returns `{:error, %HidParser.Error{}}` for an unbalanced `Push`/`Pop`.
  """
  @spec compile(ReportDescriptor.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def compile(%ReportDescriptor{items: items}, opts \\ []) do
    with :ok <- validate_push_pop(items) do
      state = %{
        global: initial_global(),
        stack: [],
        local: %{usage: nil, usage_min: nil, usage_max: nil},
        collection_usages: [],
        fields: %{},
        offsets: %{},
        uses_report_id?: false
      }

      state = compile_items(items, state)

      reports = Map.new(state.fields, fn {id, fields} -> {id, Enum.reverse(fields)} end)

      {:ok,
       %__MODULE__{
         vid: Keyword.get(opts, :vid),
         pid: Keyword.get(opts, :pid),
         reports: reports,
         uses_report_id?: state.uses_report_id?
       }}
    end
  end

  defp initial_global do
    %{
      usage_page: 0,
      logical_min: 0,
      logical_max: 0,
      physical_min: nil,
      physical_max: nil,
      unit: nil,
      unit_exponent: 0,
      report_size: 0,
      report_id: 0,
      report_count: 0
    }
  end

  defp validate_push_pop(items) do
    case push_pop_balance(items, 0) do
      {:ok, 0} -> :ok
      {:ok, _} -> {:error, Error.exception(reason: :push_without_pop)}
      {:error, reason} -> {:error, Error.exception(reason: reason)}
    end
  end

  defp push_pop_balance(items, balance) do
    Enum.reduce_while(items, {:ok, balance}, fn
      %Push{}, {:ok, balance} ->
        {:cont, {:ok, balance + 1}}

      %Pop{}, {:ok, balance} when balance > 0 ->
        {:cont, {:ok, balance - 1}}

      %Pop{}, {:ok, _balance} ->
        {:halt, {:error, :pop_without_push}}

      %Collection{items: children}, {:ok, balance} ->
        case push_pop_balance(children, balance) do
          {:ok, balance} -> {:cont, {:ok, balance}}
          {:error, _} = err -> {:halt, err}
        end

      _item, {:ok, balance} ->
        {:cont, {:ok, balance}}
    end)
  end

  defp compile_items([], state), do: state

  defp compile_items([%Collection{} = collection | rest], state) do
    state = %{state | collection_usages: [collection_usage(state) | state.collection_usages]}
    state = reset_local(state)
    state = compile_items(collection.items, state)
    state = %{state | collection_usages: tl(state.collection_usages)}
    compile_items(rest, reset_local(state))
  end

  defp compile_items([item | rest], state) do
    compile_items(rest, compile_item(item, state))
  end

  # Global items

  defp compile_item(%ReportDescriptor.UsagePage{value: v}, state),
    do: put_global(state, :usage_page, v)

  defp compile_item(%ReportDescriptor.LogicalMinimum{value: v}, state),
    do: put_global(state, :logical_min, v)

  defp compile_item(%ReportDescriptor.LogicalMaximum{value: v}, state),
    do: put_global(state, :logical_max, v)

  defp compile_item(%ReportDescriptor.PhysicalMinimum{value: v}, state),
    do: put_global(state, :physical_min, v)

  defp compile_item(%ReportDescriptor.PhysicalMaximum{value: v}, state),
    do: put_global(state, :physical_max, v)

  defp compile_item(%ReportDescriptor.UnitExponent{value: v}, state),
    do: put_global(state, :unit_exponent, v)

  defp compile_item(%ReportDescriptor.Unit{value: v}, state),
    do: put_global(state, :unit, Helper.decode_unit(v))

  defp compile_item(%ReportDescriptor.ReportSize{value: v}, state),
    do: put_global(state, :report_size, v)

  defp compile_item(%ReportDescriptor.ReportCount{value: v}, state),
    do: put_global(state, :report_count, v)

  defp compile_item(%ReportDescriptor.ReportId{value: v}, state) do
    %{state | uses_report_id?: true} |> put_global(:report_id, v)
  end

  defp compile_item(%Push{}, state), do: %{state | stack: [state.global | state.stack]}

  defp compile_item(%Pop{}, state) do
    case state.stack do
      [] -> state
      [global | rest] -> %{state | global: global, stack: rest}
    end
  end

  # Local items that feed usage state

  defp compile_item(%ReportDescriptor.Usage{value: v}, state), do: put_local(state, :usage, v)

  defp compile_item(%ReportDescriptor.UsageMinimum{value: v}, state),
    do: put_local(state, :usage_min, v)

  defp compile_item(%ReportDescriptor.UsageMaximum{value: v}, state),
    do: put_local(state, :usage_max, v)

  # Main items

  defp compile_item(%Input{flags: flags}, state), do: emit_field(state, :input, flags)
  defp compile_item(%Output{flags: flags}, state), do: emit_field(state, :output, flags)
  defp compile_item(%Feature{flags: flags}, state), do: emit_field(state, :feature, flags)

  # Remaining local items (designators/strings/delimiters) and vendor items carry
  # no report-model information. `Collection`/`EndCollection` are handled by
  # `compile_items/2`, not here.

  defp compile_item(_item, state), do: state

  defp put_global(state, key, value), do: %{state | global: Map.put(state.global, key, value)}

  defp put_local(state, key, value), do: %{state | local: Map.put(state.local, key, value)}

  defp reset_local(state), do: %{state | local: %{usage: nil, usage_min: nil, usage_max: nil}}

  defp collection_usage(state) do
    local = state.local
    page = state.global.usage_page

    cond do
      local.usage != nil ->
        {page, [local.usage]}

      local.usage_min != nil and local.usage_max != nil ->
        {page, Enum.to_list(local.usage_min..local.usage_max)}

      true ->
        nil
    end
  end

  defp emit_field(state, type, flags) do
    global = state.global
    size = global.report_size
    count = global.report_count

    if size == 0 or count == 0 do
      reset_local(state)
    else
      report_id = global.report_id
      offset = Map.get(state.offsets, report_id, 0)
      decoded = Helper.decode_flags(flags)
      {usage_page, usages} = resolve_usages(global.usage_page, state, decoded, count)
      state = reset_local(state)

      field = %Field{
        type: type,
        report_id: report_id,
        offset: offset,
        size: size,
        count: count,
        signed?: global.logical_min < 0,
        flags: decoded,
        logical_min: global.logical_min,
        logical_max: global.logical_max,
        physical_min: global.physical_min,
        physical_max: global.physical_max,
        unit: global.unit,
        unit_exponent: global.unit_exponent,
        usage_page: usage_page,
        usages: usages
      }

      %{
        state
        | fields: Map.update(state.fields, report_id, [field], &[field | &1]),
          offsets: Map.put(state.offsets, report_id, offset + size * count)
      }
    end
  end

  defp resolve_usages(usage_page, state, flags, count) do
    local = state.local

    cond do
      local.usage != nil ->
        {usage_page, [local.usage]}

      local.usage_min != nil and local.usage_max != nil ->
        if flags.variable do
          {usage_page, Enum.map(0..(count - 1), &(local.usage_min + &1))}
        else
          {usage_page, Enum.to_list(local.usage_min..local.usage_max)}
        end

      true ->
        case inherited_usage(state.collection_usages) do
          nil -> {usage_page, []}
          {page, ids} -> {page, ids}
        end
    end
  end

  defp inherited_usage([]), do: nil
  defp inherited_usage([nil | rest]), do: inherited_usage(rest)
  defp inherited_usage([usage | _]), do: usage

  # === Decode ===============================================================

  @doc """
  Decodes report bytes into a `HidParser.Report`.

  Returns `{:error, %HidParser.Error{}}` for an empty report, an unknown report
  id, or a codec with no reports.
  """
  @spec decode(t(), binary()) :: {:ok, Report.t()} | {:error, Error.t()}
  def decode(%__MODULE__{uses_report_id?: true} = codec, <<id, data::binary>>),
    do: decode_report(codec, id, data)

  def decode(%__MODULE__{uses_report_id?: true}, <<>>),
    do: {:error, Error.exception(reason: :empty_report)}

  def decode(%__MODULE__{uses_report_id?: false} = codec, data) when is_binary(data) do
    case Map.keys(codec.reports) do
      [id] -> decode_report(codec, id, data)
      [] -> {:error, Error.exception(reason: :no_reports)}
    end
  end

  defp decode_report(codec, id, data) do
    case Map.fetch(codec.reports, id) do
      {:ok, fields} -> {:ok, %Report{report_id: id, values: decode_values(fields, data)}}
      :error -> {:error, Error.exception(reason: :unknown_report_id, detail: id)}
    end
  end

  defp decode_values(fields, data) do
    int = :binary.decode_unsigned(data, :little)

    fields
    |> Enum.reject(& &1.flags.constant)
    |> Enum.flat_map(fn field ->
      int
      |> decode_field(field)
      |> Enum.with_index()
      |> Enum.map(fn {logical, index} -> %Value{field: field, index: index, logical: logical} end)
    end)
  end

  defp decode_field(int, field) do
    for i <- 0..(field.count - 1) do
      raw = int >>> (field.offset + i * field.size) &&& mask(field.size)

      if field.signed?, do: sign_extend(raw, field.size), else: raw
    end
  end

  # === Encode ===============================================================

  @doc """
  Encodes a `HidParser.Report` back into report bytes.

  Returns `{:error, %HidParser.Error{}}` for an unknown report id, or for values
  that don't match the codec's fields (missing/extra fields, wrong element
  counts, or out-of-range logical values).
  """
  @spec encode(t(), Report.t()) :: {:ok, binary()} | {:error, Error.t()}
  def encode(%__MODULE__{} = codec, %Report{report_id: id, values: values}) do
    case Map.fetch(codec.reports, id) do
      {:ok, fields} ->
        with {:ok, acc} <- pack_report(fields, values, 0) do
          {:ok, encode_binary(codec, id, fields, acc)}
        end

      :error ->
        {:error, Error.exception(reason: :unknown_report_id, detail: id)}
    end
  end

  defp pack_report(fields, values, acc) do
    expected = Enum.reject(fields, & &1.flags.constant)

    with :ok <- validate_membership(expected, values) do
      validate_and_pack(expected, values, acc)
    end
  end

  defp validate_membership(expected, values) do
    keys = values |> Enum.group_by(& &1.field) |> Map.keys()

    cond do
      keys -- expected != [] ->
        {:error, Error.exception(reason: :field_mismatch, detail: hd(keys -- expected))}

      expected -- keys != [] ->
        {:error, Error.exception(reason: :missing_values, detail: hd(expected -- keys))}

      true ->
        :ok
    end
  end

  defp validate_and_pack(expected, values, acc) do
    grouped = Enum.group_by(values, & &1.field)

    Enum.reduce_while(expected, {:ok, acc}, fn
      _field, {:error, _} = err -> {:halt, err}
      field, {:ok, acc} -> pack_field_values(field, grouped, acc)
    end)
  end

  defp pack_field_values(field, grouped, acc) do
    field_values = Map.get(grouped, field) |> Enum.sort_by(& &1.index)

    case validate_field(field, field_values) do
      :ok -> {:cont, {:ok, pack_values(field_values, acc)}}
      {:error, _} = err -> {:halt, err}
    end
  end

  defp pack_values(field_values, acc) do
    Enum.reduce(field_values, acc, fn value, acc -> pack_value(value, acc) end)
  end

  defp validate_field(field, field_values) do
    cond do
      length(field_values) != field.count ->
        {:error,
         Error.exception(reason: :value_count_mismatch, detail: {field, length(field_values)})}

      Enum.map(field_values, & &1.index) != Enum.to_list(0..(field.count - 1)) ->
        {:error,
         Error.exception(reason: :value_count_mismatch, detail: {field, length(field_values)})}

      true ->
        validate_range(field, field_values)
    end
  end

  defp validate_range(field, field_values) do
    Enum.find_value(field_values, :ok, &range_error(field, &1))
  end

  defp range_error(field, value) do
    if value.logical < field.logical_min or value.logical > field.logical_max,
      do: {:error, Error.exception(reason: :out_of_range, detail: {field, value.logical})}
  end

  defp pack_value(%Value{field: field, index: index, logical: logical}, acc) do
    acc ||| (logical &&& mask(field.size)) <<< (field.offset + index * field.size)
  end

  defp encode_binary(codec, id, fields, acc) do
    total_bits = Enum.reduce(fields, 0, fn field, n -> n + field.size * field.count end)
    byte_len = div(total_bits + 7, 8)

    data =
      if total_bits == 0 do
        <<>>
      else
        <<acc::little-unsigned-integer-size(byte_len * 8)>>
      end

    if codec.uses_report_id?, do: <<id, data::binary>>, else: data
  end

  # === Bit helpers ==========================================================

  defp mask(n), do: (1 <<< n) - 1

  defp sign_extend(v, n) do
    if (v &&& 1 <<< (n - 1)) != 0, do: v - (1 <<< n), else: v
  end
end

defimpl Inspect, for: HidParser.ReportCodec do
  import Inspect.Algebra

  def inspect(codec, opts) do
    if opts.custom_options[:verbose] do
      Inspect.Any.inspect(codec, opts)
    else
      concat([
        "#ReportCodec<",
        "vid: ",
        hex(codec.vid),
        ", pid: ",
        hex(codec.pid),
        ", ",
        to_string(map_size(codec.reports)),
        " reports>"
      ])
    end
  end

  defp hex(nil), do: "nil"

  defp hex(n), do: "0x" <> String.upcase(String.pad_leading(Integer.to_string(n, 16), 4, "0"))
end
