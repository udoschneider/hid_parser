defmodule HidParser.Report do
  @moduledoc """
  Compiles a HID report descriptor into a field model and parses/builds reports
  against it.

  This is the second of three layers: the descriptor parser
  (`HidParser.ReportDescriptor`) produces *items* (syntax only); this module
  "compiles" those items into a per-report list of `t:HidParser.Report.Field.t/0`
  by resolving global/local item state, `Push`/`Pop`, collection nesting, report
  IDs and usage inheritance. The compiled model can then parse a binary report
  into canonical logical values and build the binary back, with a clean
  roundtrip:

      report = HidParser.Report.compile(descriptor)
      {:ok, values} = HidParser.Report.parse(report, binary)
      {:ok, ^binary} = HidParser.Report.build(report, values)

  ## Value model

  Canonical values are an ordered list of `{field, values}` where `values` is
  the logical integer(s) for the field — one entry per element (`field.count` of
  them), always. Constant fields never appear: they are descriptor-driven and
  roundtrip as zero bits. Physical/SI scaling is exposed through
  `physical/2` and `scaled/2`, never stored.

  ## Bit packing

  Fields are packed LSB-first in field order; a count-N field contributes N
  consecutive values of `size` bits each. A report that uses report IDs prefixes
  the id byte to every report.
  """

  import Bitwise

  alias HidParser.Report.Field
  alias HidParser.ReportDescriptor, as: RD
  alias HidParser.ReportDescriptor.Helper

  @type values :: [{Field.t(), [integer()]}]

  @type t :: %__MODULE__{
          vid: integer() | nil,
          pid: integer() | nil,
          reports: %{optional(integer()) => [Field.t()]},
          uses_report_id?: boolean()
        }

  defstruct vid: nil, pid: nil, reports: %{}, uses_report_id?: false

  # === Compile ==============================================================

  @doc """
  Compiles a report descriptor binary into a `t:t/0`.

  Options:

    * `:vid`, `:pid` — device metadata stored verbatim on the report.
    * `:report_id` — the key under which the single report is stored when the
      descriptor has no report IDs (default `0`). Ignored when the descriptor
      itself uses report IDs.

  Raises `ArgumentError` on a structurally invalid descriptor (unbalanced
  `Push`/`Pop` or `Collection`/`EndCollection`).
  """
  @spec compile(binary(), keyword()) :: t()
  def compile(descriptor, opts \\ []) when is_binary(descriptor) do
    items = RD.parse_items(descriptor)

    # The report_id option only matters when the descriptor has no report IDs;
    # a descriptor that declares its own ReportId items ignores it.
    report_id =
      if Enum.any?(items, &match?(%RD.ReportId{}, &1)),
        do: 0,
        else: Keyword.get(opts, :report_id, 0)

    state = %{
      global: %{
        usage_page: 0,
        logical_min: 0,
        logical_max: 0,
        physical_min: nil,
        physical_max: nil,
        unit: nil,
        unit_exponent: 0,
        report_size: 0,
        report_id: report_id,
        report_count: 0
      },
      stack: [],
      local: %{usage: nil, usage_min: nil, usage_max: nil},
      collection_usages: [],
      fields: %{},
      offsets: %{},
      uses_report_id?: false
    }

    state = Enum.reduce(items, state, &compile_item/2)

    if state.stack != [] do
      raise ArgumentError, "Pop without a matching Push"
    end

    if state.collection_usages != [] do
      raise ArgumentError, "EndCollection missing for one or more collections"
    end

    reports = Map.new(state.fields, fn {id, fields} -> {id, Enum.reverse(fields)} end)

    %__MODULE__{
      vid: Keyword.get(opts, :vid),
      pid: Keyword.get(opts, :pid),
      reports: reports,
      uses_report_id?: state.uses_report_id?
    }
  end

  # Global items

  defp compile_item(%RD.UsagePage{value: v}, state), do: put_global(state, :usage_page, v)
  defp compile_item(%RD.LogicalMinimum{value: v}, state), do: put_global(state, :logical_min, v)
  defp compile_item(%RD.LogicalMaximum{value: v}, state), do: put_global(state, :logical_max, v)

  defp compile_item(%RD.PhysicalMinimum{value: v}, state),
    do: put_global(state, :physical_min, v)

  defp compile_item(%RD.PhysicalMaximum{value: v}, state),
    do: put_global(state, :physical_max, v)

  defp compile_item(%RD.UnitExponent{value: v}, state), do: put_global(state, :unit_exponent, v)

  defp compile_item(%RD.Unit{value: v}, state),
    do: put_global(state, :unit, Helper.decode_unit(v))

  defp compile_item(%RD.ReportSize{value: v}, state), do: put_global(state, :report_size, v)
  defp compile_item(%RD.ReportCount{value: v}, state), do: put_global(state, :report_count, v)

  defp compile_item(%RD.ReportId{value: v}, state) do
    %{state | uses_report_id?: true} |> put_global(:report_id, v)
  end

  defp compile_item(%RD.Push{}, state), do: %{state | stack: [state.global | state.stack]}

  defp compile_item(%RD.Pop{}, state) do
    case state.stack do
      [] -> raise ArgumentError, "Pop without a matching Push"
      [global | rest] -> %{state | global: global, stack: rest}
    end
  end

  # Local items that feed usage state

  defp compile_item(%RD.Usage{value: v}, state), do: put_local(state, :usage, v)

  defp compile_item(%RD.UsageMinimum{value: v}, state), do: put_local(state, :usage_min, v)

  defp compile_item(%RD.UsageMaximum{value: v}, state), do: put_local(state, :usage_max, v)

  # Main items

  defp compile_item(%RD.Input{flags: flags}, state), do: emit_field(state, :input, flags)
  defp compile_item(%RD.Output{flags: flags}, state), do: emit_field(state, :output, flags)
  defp compile_item(%RD.Feature{flags: flags}, state), do: emit_field(state, :feature, flags)

  defp compile_item(%RD.Collection{}, state) do
    %{state | collection_usages: [collection_usage(state) | state.collection_usages]}
    |> reset_local()
  end

  defp compile_item(%RD.EndCollection{}, state) do
    case state.collection_usages do
      [] -> raise ArgumentError, "EndCollection without a matching Collection"
      [_ | rest] -> state |> Map.put(:collection_usages, rest) |> reset_local()
    end
  end

  # Remaining local items (designators/strings/delimiters) and vendor items carry
  # no report-model information.

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

  # === Parse ================================================================

  @doc """
  Parses a binary report into canonical values.

  Returns `{:ok, values}` where `values` is an ordered list of `{field, values}`
  tuples (logical integers), or `{:error, reason}` for a malformed report or an
  unknown report id.
  """
  @spec parse(t(), binary()) :: {:ok, values()} | {:error, term()}
  def parse(%__MODULE__{uses_report_id?: true} = report, <<id, data::binary>>),
    do: decode_report(report, id, data)

  def parse(%__MODULE__{uses_report_id?: true}, <<>>), do: {:error, :empty_report}

  def parse(%__MODULE__{uses_report_id?: false} = report, data) when is_binary(data) do
    case Map.keys(report.reports) do
      [id] -> decode_report(report, id, data)
      [] -> {:error, :no_reports}
      _ -> {:error, :ambiguous_report_id}
    end
  end

  defp decode_report(report, id, data) do
    case Map.fetch(report.reports, id) do
      {:ok, fields} -> {:ok, decode_fields(fields, data)}
      :error -> {:error, {:unknown_report_id, id}}
    end
  end

  defp decode_fields(fields, data) do
    int = :binary.decode_unsigned(data, :little)

    for %Field{flags: %{constant: false}} = field <- fields do
      {field, decode_field(int, field)}
    end
  end

  defp decode_field(int, field) do
    for i <- 0..(field.count - 1) do
      raw = int >>> (field.offset + i * field.size) &&& mask(field.size)

      if field.signed?, do: sign_extend(raw, field.size), else: raw
    end
  end

  # === Build ================================================================

  @doc """
  Builds a binary report from canonical values.

  `values` must list the non-constant fields in report order; constant fields
  are packed as zero bits. Returns `{:ok, binary}` or `{:error, reason}` for
  missing/extra values or out-of-range integers.
  """
  @spec build(t(), values()) :: {:ok, binary()} | {:error, term()}
  def build(%__MODULE__{} = report, values) when is_list(values) do
    with {:ok, id} <- report_id_for_build(report, values),
         {:ok, fields} <- Map.fetch(report.reports, id) do
      case pack_fields(fields, values, 0) do
        {:ok, acc, []} -> {:ok, encode_report(report, id, fields, acc)}
        {:ok, _acc, leftover} -> {:error, {:extra_values, leftover}}
        {:error, _} = err -> err
      end
    end
  end

  defp report_id_for_build(_report, [{%Field{} = field, _} | _]), do: {:ok, field.report_id}

  defp report_id_for_build(report, []) do
    case Map.keys(report.reports) do
      [id] -> {:ok, id}
      [] -> {:error, :no_reports}
      _ -> {:error, :ambiguous_report_id}
    end
  end

  defp pack_fields(fields, values, acc) do
    Enum.reduce_while(fields, {:ok, acc, values}, fn
      _field, {:error, _} = err ->
        {:halt, err}

      %Field{flags: %{constant: true}}, {:ok, acc, vals} ->
        {:cont, {:ok, acc, vals}}

      field, {:ok, acc, vals} ->
        {:cont, pack_data_field(field, acc, vals)}
    end)
  end

  defp pack_data_field(field, acc, vals) do
    with {:ok, field_vals, rest} <- take_values(vals, field),
         :ok <- validate_values(field, field_vals) do
      {:ok, pack_field(acc, field, field_vals), rest}
    end
  end

  defp take_values([{field, vals} | rest], field) when length(vals) == field.count,
    do: {:ok, vals, rest}

  defp take_values([{field, vals} | _rest], field),
    do: {:error, {:value_count_mismatch, field, length(vals)}}

  defp take_values([{other, _} | _], field), do: {:error, {:field_mismatch, field, other}}
  defp take_values([], field), do: {:error, {:missing_values, field}}

  defp validate_values(field, field_vals) do
    Enum.find_value(field_vals, :ok, fn v ->
      if v < field.logical_min or v > field.logical_max,
        do: {:error, {:out_of_range, field, v}},
        else: nil
    end)
  end

  defp pack_field(acc, field, field_vals) do
    Enum.reduce(Enum.with_index(field_vals), acc, fn {v, i}, acc ->
      acc ||| (v &&& mask(field.size)) <<< (field.offset + i * field.size)
    end)
  end

  defp encode_report(report, id, fields, acc) do
    total_bits = Enum.reduce(fields, 0, fn field, n -> n + field.size * field.count end)
    byte_len = div(total_bits + 7, 8)

    data =
      if total_bits == 0 do
        <<>>
      else
        <<acc::little-unsigned-integer-size(byte_len * 8)>>
      end

    if report.uses_report_id?, do: <<id, data::binary>>, else: data
  end

  # === Value accessors ======================================================

  @doc """
  Returns the logical value of `v` (the canonical form; identity).

  ## Examples

      iex> HidParser.Report.value(%HidParser.Report.Field{}, -3)
      -3

  """
  @spec value(Field.t(), integer()) :: integer()
  def value(_field, v), do: v

  @doc """
  Linearly maps a logical value to its physical value.

  Returns `nil` when the field declares no physical range or the logical range
  is degenerate (it cannot be scaled).

  ## Examples

      iex> field = %HidParser.Report.Field{logical_min: 0, logical_max: 100, physical_min: 0, physical_max: 1000}
      iex> HidParser.Report.physical(field, 50)
      500.0

  """
  @spec physical(Field.t(), integer()) :: float() | nil
  def physical(%Field{physical_min: nil}, _v), do: nil
  def physical(%Field{physical_max: nil}, _v), do: nil
  def physical(%Field{logical_min: lo, logical_max: hi}, _v) when hi == lo, do: nil

  def physical(
        %Field{logical_min: lo, logical_max: hi, physical_min: pmin, physical_max: pmax},
        v
      ) do
    v * (pmax - pmin) / (hi - lo) + pmin
  end

  @doc """
  Returns the SI value of `v`: its physical value scaled by
  `10^unit_exponent`.

  Returns `nil` when `physical/2` does.
  """
  @spec scaled(Field.t(), integer()) :: float() | nil
  def scaled(%Field{} = field, v) do
    case physical(field, v) do
      nil -> nil
      physical -> physical * :math.pow(10, field.unit_exponent)
    end
  end

  # === Convenience ==========================================================

  @doc """
  Flattens canonical values into a convenience list, one entry per element.

  Each entry is `{usage_name, %{usage_page: page, usage_id: id, value: v}}`,
  keyed by the usage *name* (or a `page:usage` fallback when the id is not in
  the usage tables). A count-N field yields N entries; a shared usage is
  repeated. This layer is opt-in and lossy when usages collide — the canonical
  values remain the source of truth.
  """
  @spec to_keyword(t(), values()) :: [{String.t(), map()}]
  def to_keyword(_report, values) do
    for {field, field_vals} <- values, {v, i} <- Enum.with_index(field_vals) do
      usage_id = element_usage_id(field, i, v)

      {usage_label(field.usage_page, usage_id),
       %{usage_page: field.usage_page, usage_id: usage_id, value: v}}
    end
  end

  defp element_usage_id(%Field{flags: %{variable: true}} = field, i, _v) do
    case field.usages do
      [single] -> single
      usages -> Enum.at(usages, i, List.first(usages))
    end
  end

  # An array element's value *is* the usage id it selects.
  defp element_usage_id(%Field{}, _i, v), do: v

  defp usage_label(page, nil), do: "0x" <> Integer.to_string(page, 16) <> ":unknown"

  defp usage_label(page, id) do
    RD.usage_name(page, id) ||
      "0x" <> Integer.to_string(page, 16) <> ":" <> Integer.to_string(id, 16)
  end

  # === Bit helpers ==========================================================

  defp mask(n), do: (1 <<< n) - 1

  defp sign_extend(v, n) do
    if (v &&& 1 <<< (n - 1)) != 0, do: v - (1 <<< n), else: v
  end
end
