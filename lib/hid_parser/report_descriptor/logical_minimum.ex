defmodule HidParser.ReportDescriptor.LogicalMinimum do
  # Global
  use HidParser.ReportDescriptor.Item, decoder: :parse_signed
end
