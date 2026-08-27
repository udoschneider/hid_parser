defmodule HidParser.Report.Value do
  @moduledoc """
  A single element's value within a parsed `HidParser.Report`.

  One `%Value{}` exists per element, not per field: a `count`-N field yields N
  values. `field` + `index` + `logical` pin the exact bit the value occupies, so
  the list of values roundtrips losslessly. Only the logical integer is stored;
  physical/SI values and the usage are derived on demand.
  """

  alias HidParser.ReportCodec.Field

  @type t :: %__MODULE__{
          field: Field.t(),
          index: non_neg_integer(),
          logical: integer()
        }

  @enforce_keys [:field, :index, :logical]
  defstruct [:field, :index, :logical]

  @doc """
  Returns the logical (canonical) value.
  """
  @spec logical(t()) :: integer()
  def logical(%__MODULE__{logical: logical}), do: logical

  @doc """
  Returns the physical value, or `nil` when the field declares no physical range
  or its logical range is degenerate (it cannot be scaled).

  ## Examples

      iex> field = %HidParser.ReportCodec.Field{
      ...>   logical_min: 0, logical_max: 100, physical_min: 0, physical_max: 1000
      ...> }
      iex> value = %HidParser.Report.Value{field: field, index: 0, logical: 50}
      iex> HidParser.Report.Value.physical(value)
      500.0

  """
  @spec physical(t()) :: float() | nil
  def physical(%__MODULE__{field: %Field{physical_min: nil}}), do: nil
  def physical(%__MODULE__{field: %Field{physical_max: nil}}), do: nil

  # An explicit physical range of 0..0 means "physical equals logical"
  # (HID 1.11 §6.2.2.7); it is the idiomatic way to *reset* a previous range.
  def physical(%__MODULE__{field: %Field{physical_min: 0, physical_max: 0}, logical: logical}),
    do: logical * 1.0

  def physical(%__MODULE__{field: %Field{logical_min: lo, logical_max: hi}}) when hi == lo,
    do: nil

  def physical(%__MODULE__{field: field, logical: logical}) do
    logical * (field.physical_max - field.physical_min) /
      (field.logical_max - field.logical_min) + field.physical_min
  end

  @doc """
  Returns the SI value of this element: its physical value scaled by
  `10^unit_exponent`. Returns `nil` when `physical/1` does.
  """
  @spec scaled(t()) :: float() | nil
  def scaled(%__MODULE__{} = value) do
    case physical(value) do
      nil -> nil
      physical -> physical * :math.pow(10, value.field.unit_exponent)
    end
  end

  @doc """
  Returns the usage identity `{usage_page, usage_id}` for this element.
  """
  @spec usage(t()) :: {integer(), integer() | nil}
  def usage(%__MODULE__{field: field, index: index, logical: logical}) do
    {field.usage_page, element_usage_id(field, index, logical)}
  end

  @doc """
  Returns the usage name, or a `"0xpage:0xusage"` fallback when the usage is not
  in the usage tables.
  """
  @spec name(t()) :: String.t()
  def name(%__MODULE__{} = value) do
    {page, id} = usage(value)
    usage_label(page, id)
  end

  defp element_usage_id(%Field{flags: %{variable: true}} = field, index, _logical) do
    case field.usages do
      [single] -> single
      usages -> Enum.at(usages, index, List.first(usages))
    end
  end

  # An array element's report value *is* the usage id it selects from the
  # declared range (HID 1.11 §6.2.2.8). A single `Usage` item, though, applies
  # one fixed id to every element — exactly as it does for a variable field.
  defp element_usage_id(%Field{usages: [single]}, _index, _logical), do: single

  defp element_usage_id(%Field{}, _index, logical), do: logical

  defp usage_label(page, nil), do: "0x" <> hex(page) <> ":unknown"

  defp usage_label(page, id) do
    HidParser.ReportDescriptor.usage_name(page, id) ||
      "0x" <> hex(page) <> ":0x" <> hex(id)
  end

  defp hex(n), do: Integer.to_string(n, 16)
end

defimpl Inspect, for: HidParser.Report.Value do
  import Inspect.Algebra

  def inspect(value, opts) do
    if opts.custom_options[:verbose] do
      Inspect.Any.inspect(value, opts)
    else
      concat([
        "#Report.Value<",
        HidParser.Report.Value.name(value),
        " = ",
        to_doc(value.logical, opts),
        ">"
      ])
    end
  end
end
