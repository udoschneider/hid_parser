defmodule HidParser.ReportDescriptor.PhysicalMinimum do
  # Global
  use HidParser.ReportDescriptor.Item, decoder: :parse_signed
end
