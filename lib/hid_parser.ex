defmodule HidParser do
  def parse_report_descriptor(binary) when is_binary(binary),
    do: HidParser.ReportDescriptor.parse_items(binary)
end
