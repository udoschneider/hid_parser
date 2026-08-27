defmodule HidParser.ReportDescriptor.PhysicalMaximum do
  @moduledoc """
  Global item: the maximum physical value for a report field. See HID 1.11 §6.2.2.7.
  """

  use HidParser.ReportDescriptor.Item, decoder: :parse_signed
end
