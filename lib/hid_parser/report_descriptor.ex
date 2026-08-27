defmodule HidParser.ReportDescriptor do
  @moduledoc """
  `HidParser` parses a binary into a list of report descriptor items.
  """

  alias HidParser.ReportDescriptor.Helper

  # Implement ReportDesriptor parsing à la

  # Main Items
  alias HidParser.ReportDescriptor.{Input, Output, Feature, Collection, EndCollection, Reserved}

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

  def parse_items(binary) when is_binary(binary) do
    binary |> parse_items([])
  end

  defp parse_items(<<>>, acc), do: Enum.reverse(acc)

  # credo:disable-for-next-line Credo.Check.Readability.VariableNames
  defp parse_items(<<bTag::4, bType::2, bSize::2, bytes::binary>>, acc) do
    size = Helper.shortsize_expand(bSize)
    <<data::binary-size(^size), rest::binary>> = bytes
    raw = <<bTag::4, bType::2, bSize::2>> <> data
    item = new_item(bType, bTag, data, raw)
    parse_items(rest, [item | acc])
  end

  @doc """
  Builds the nested collection tree from a flat list of items.

  Each `Collection` accumulates its child items into `items` and records the
  matching `EndCollection` flags in `end_flags`.

  ## Examples

      iex> HidParser.ReportDescriptor.parse_collections([
      ...>   %HidParser.ReportDescriptor.Collection{flags: 1},
      ...>   %HidParser.ReportDescriptor.EndCollection{flags: 0}
      ...> ])
      [%HidParser.ReportDescriptor.Collection{flags: 1, items: [], end_flags: 0}]
  """
  def parse_collections(items) when is_list(items) do
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
