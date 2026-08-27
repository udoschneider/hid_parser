defmodule HidParser do
  @moduledoc """
  Parses USB HID report descriptors into structured items.
  """

  @doc """
  Parses a report descriptor binary into a flat list of items.
  """
  def parse_report_descriptor(binary) when is_binary(binary),
    do: HidParser.ReportDescriptor.parse_items(binary)

  @doc """
  Parses a report descriptor binary into a nested collection tree.
  """
  def parse_report_descriptor_tree(binary) when is_binary(binary) do
    binary
    |> HidParser.ReportDescriptor.parse_items()
    |> HidParser.ReportDescriptor.parse_collections()
  end
end
