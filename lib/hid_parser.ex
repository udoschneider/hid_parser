defmodule HidParser do
  @moduledoc """
  Parses and works with USB HID report descriptors (HID 1.11).

  The library has two layers:

    * **Descriptor items** — `parse_report_descriptor/1` and
      `parse_report_descriptor_tree/1` decode a descriptor binary into
      `HidParser.ReportDescriptor` item structs (syntax only).
    * **Report model** — `HidParser.Report.compile/2` turns those items into a
      per-report field model, and `HidParser.Report.parse/2` /
      `HidParser.Report.build/2` convert between binary reports and canonical
      logical values.

  ## Examples

      iex> HidParser.parse_report_descriptor(<<0x05, 0x01, 0x09, 0x06>>)
      [
        %HidParser.ReportDescriptor.UsagePage{value: 1},
        %HidParser.ReportDescriptor.Usage{value: 6}
      ]

  For report parsing/building and value scaling, see `HidParser.Report`.
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
