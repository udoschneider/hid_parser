defmodule HidParser.ReportDescriptor do
  @moduledoc """
  A parsed HID report descriptor: the collection tree of items.

  `parse/1` decodes a descriptor binary into this tree, which is the canonical
  (syntax-level) representation of the descriptor. The tree preserves the
  nesting declared by `Collection` items; the flat item list is an internal
  detail. See HID 1.11 §6.2.2.

  The individual item structs live under this module (e.g.
  `HidParser.ReportDescriptor.Input`, `HidParser.ReportDescriptor.Collection`).
  The usage-table lookups (`usage_pages/0`, `usage_page_name/1`,
  `usage_name/2`) are exposed here as well, and are shared by
  `HidParser.Report.Value.name/1`.
  """

  alias HidParser.ReportDescriptor.Helper

  # Main Items
  alias HidParser.ReportDescriptor.{Input, Output, Feature, Collection, EndCollection, Reserved}

  alias HidParser.ReportDescriptor.LongItem

  # Global Items
  alias HidParser.ReportDescriptor.{
    UsagePage,
    LogicalMinimum,
    LogicalMaximum,
    PhysicalMinimum,
    PhysicalMaximum,
    UnitExponent,
    Unit,
    ReportSize,
    ReportId,
    ReportCount,
    Push,
    Pop
  }

  # Local Items
  alias HidParser.ReportDescriptor.{
    Usage,
    UsageMinimum,
    UsageMaximum,
    DesignatorIndex,
    DesignatorMinimum,
    DesignatorMaximum,
    StringIndex,
    StringMinimum,
    StringMaximum,
    Delimiter
  }

  @usage_pages_file "priv/static/HidUsageTables.json"

  @type t :: %__MODULE__{items: [term()]}

  defstruct items: []

  @doc """
  Parses a report descriptor binary into a `t:t/0` collection tree.

  Returns `{:error, %HidParser.Error{reason: :invalid_descriptor}}` for a
  malformed or truncated descriptor.

  ## Examples

      iex> {:ok, %HidParser.ReportDescriptor{items: [item]}} =
      ...>   HidParser.ReportDescriptor.parse(<<0x05, 0x01>>)
      iex> item
      %HidParser.ReportDescriptor.UsagePage{value: 1}

  """
  @spec parse(binary()) :: {:ok, t()} | {:error, HidParser.Error.t()}
  def parse(binary) when is_binary(binary) do
    {:ok, %__MODULE__{items: binary |> parse_items() |> parse_collections()}}
  rescue
    MatchError -> {:error, HidParser.Error.exception(reason: :invalid_descriptor)}
    FunctionClauseError -> {:error, HidParser.Error.exception(reason: :invalid_descriptor)}
  end

  @doc """
  Returns the HID usage tables, parsed from `priv/static/HidUsageTables.json`.

  Parsed lazily on first call and cached in `:persistent_term`, so the JSON is
  only read (and decoded) when it is actually needed, and never during
  compilation.
  """
  def usage_pages() do
    :persistent_term.get({__MODULE__, :usage_pages}, nil) || load_usage_pages()
  end

  defp load_usage_pages() do
    pages =
      Application.app_dir(:hid_parser, @usage_pages_file)
      |> HidParser.ReportDescriptor.UsagePageParser.parse()

    :persistent_term.put({__MODULE__, :usage_pages}, pages)
    pages
  end

  @doc """
  Returns the name of a usage page, or `nil` if it is not in the usage tables.

  ## Examples

      iex> HidParser.ReportDescriptor.usage_page_name(1)
      "Generic Desktop"

  """
  @spec usage_page_name(integer()) :: String.t() | nil
  def usage_page_name(usage_page) do
    case usage_pages() do
      %{^usage_page => %{name: name}} -> name
      _ -> nil
    end
  end

  @doc """
  Returns the name of a usage within a usage page, or `nil` if it is not in the
  usage tables.

  ## Examples

      iex> HidParser.ReportDescriptor.usage_name(1, 6)
      "Keyboard"

  """
  @spec usage_name(integer(), integer()) :: String.t() | nil
  def usage_name(usage_page, usage_id) do
    case usage_pages() do
      %{^usage_page => %{usage_ids: %{^usage_id => %{name: name}}}} -> name
      _ -> nil
    end
  end

  defp parse_items(binary) when is_binary(binary) do
    binary |> parse_items([])
  end

  defp parse_items(<<>>, acc), do: Enum.reverse(acc)

  # Long item (HID 1.11 §6.2.2.3): 0xFF prefix, then an 8-bit tag and 8-bit data size.
  defp parse_items(<<0xFF, tag::8, data_size::8, bytes::binary>>, acc) do
    <<data::binary-size(^data_size), rest::binary>> = bytes
    parse_items(rest, [LongItem.new(tag, data) | acc])
  end

  # credo:disable-for-next-line Credo.Check.Readability.VariableNames
  defp parse_items(<<bTag::4, bType::2, bSize::2, bytes::binary>>, acc) do
    size = Helper.shortsize_expand(bSize)
    <<data::binary-size(^size), rest::binary>> = bytes
    raw = <<bTag::4, bType::2, bSize::2>> <> data
    item = new_item(bType, bTag, data, raw)
    parse_items(rest, [item | acc])
  end

  # Builds the nested collection tree from a flat list of items: each `Collection`
  # accumulates its child items into `items` and records the matching
  # `EndCollection` flags in `end_flags`.
  defp parse_collections(items) when is_list(items) do
    {acc, _end_flags, []} = parse_nodes(items, [])
    Enum.reverse(acc)
  end

  defp parse_nodes([], acc), do: {acc, nil, []}

  defp parse_nodes([%EndCollection{flags: flags} | rest], acc), do: {acc, flags, rest}

  defp parse_nodes([%Collection{} = col | rest], acc) do
    {children, end_flags, remaining} = parse_nodes(rest, [])
    col = %{col | items: Enum.reverse(children), end_flags: end_flags || 0}
    parse_nodes(remaining, [col | acc])
  end

  defp parse_nodes([item | rest], acc), do: parse_nodes(rest, [item | acc])

  defp new_item(0b00, 0b1000, data, _raw), do: Input.new(data)
  defp new_item(0b00, 0b1001, data, _raw), do: Output.new(data)
  defp new_item(0b00, 0b1011, data, _raw), do: Feature.new(data)
  defp new_item(0b00, 0b1010, data, _raw), do: Collection.new(data)
  defp new_item(0b00, 0b1100, data, _raw), do: EndCollection.new(data)

  defp new_item(0b01, 0b0000, data, _raw), do: UsagePage.new(data)
  defp new_item(0b01, 0b0001, data, _raw), do: LogicalMinimum.new(data)
  defp new_item(0b01, 0b0010, data, _raw), do: LogicalMaximum.new(data)
  defp new_item(0b01, 0b0011, data, _raw), do: PhysicalMinimum.new(data)
  defp new_item(0b01, 0b0100, data, _raw), do: PhysicalMaximum.new(data)
  defp new_item(0b01, 0b0101, data, _raw), do: UnitExponent.new(data)
  defp new_item(0b01, 0b0110, data, _raw), do: Unit.new(data)
  defp new_item(0b01, 0b0111, data, _raw), do: ReportSize.new(data)
  defp new_item(0b01, 0b1000, data, _raw), do: ReportId.new(data)
  defp new_item(0b01, 0b1001, data, _raw), do: ReportCount.new(data)
  defp new_item(0b01, 0b1010, data, _raw), do: Push.new(data)
  defp new_item(0b01, 0b1011, data, _raw), do: Pop.new(data)

  defp new_item(0b10, 0b0000, data, _raw), do: Usage.new(data)
  defp new_item(0b10, 0b0001, data, _raw), do: UsageMinimum.new(data)
  defp new_item(0b10, 0b0010, data, _raw), do: UsageMaximum.new(data)
  defp new_item(0b10, 0b0011, data, _raw), do: DesignatorIndex.new(data)
  defp new_item(0b10, 0b0100, data, _raw), do: DesignatorMinimum.new(data)
  defp new_item(0b10, 0b0101, data, _raw), do: DesignatorMaximum.new(data)
  defp new_item(0b10, 0b0111, data, _raw), do: StringIndex.new(data)
  defp new_item(0b10, 0b1000, data, _raw), do: StringMinimum.new(data)
  defp new_item(0b10, 0b1001, data, _raw), do: StringMaximum.new(data)
  defp new_item(0b10, 0b1010, data, _raw), do: Delimiter.new(data)

  defp new_item(_bType, _bTag, _data, raw), do: Reserved.new(raw)
end

defimpl Inspect, for: HidParser.ReportDescriptor do
  import Inspect.Algebra

  def inspect(descriptor, opts) do
    if opts.custom_options[:verbose] do
      Inspect.Any.inspect(descriptor, opts)
    else
      {collections, items} = count(descriptor.items)

      concat([
        "#ReportDescriptor<",
        to_string(collections),
        " collections, ",
        to_string(items),
        " items>"
      ])
    end
  end

  defp count(items) do
    Enum.reduce(items, {0, 0}, fn
      %HidParser.ReportDescriptor.Collection{items: children}, {collections, items} ->
        {cc, ci} = count(children)
        {collections + 1 + cc, items + 1 + ci}

      _item, {collections, items} ->
        {collections, items + 1}
    end)
  end
end
