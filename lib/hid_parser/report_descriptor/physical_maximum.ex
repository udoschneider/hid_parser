defmodule HidParser.ReportDescriptor.PhysicalMaximum do
  # Global
  use HidParser.ReportDescriptor.Item, decoder: :parse_signed
end
