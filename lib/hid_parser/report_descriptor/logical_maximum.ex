defmodule HidParser.ReportDescriptor.LogicalMaximum do
  # Global
  use HidParser.ReportDescriptor.Item, decoder: :parse_signed
end
