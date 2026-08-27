defmodule HidParser.ReportDescriptor do
  @moduledoc """
  `HidParser` parses a binary into a list of report descriptor items.
  """

  alias HidParser.Helper

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

  @usage_pages Application.app_dir(:hid_parser, "priv/static/HidUsageTables.json")
               |> HidParser.ReportDescriptor.UsagePageParser.parse()

  def usage_pages(), do: @usage_pages

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

  defp parse_collections(items), do: parse_collections(items, [[]])

  defp parse_collections([%Collection{} = col | items], [top | stack]),
    do: parse_collections(items, [[] | [[col | top] | stack]])

  defp parse_collections([%EndCollection{} = end_col | items], [children | [[col | rest]]]) do
    col = %{col | items: Enum.reverse(children), end_flags: end_col.flags}
    parse_collections(items, [col | rest])
  end

  defp parse_collections([item | items], [top | stack]),
    do: parse_collections(items, [[item | top] | stack])

  defp parse_collections([], acc), do: Enum.reverse(acc)

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
