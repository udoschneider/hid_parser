defmodule HidParser.ReportDescriptor.LogicalMaximum do
  @moduledoc """
  Global item: the maximum value a report field can take. See HID 1.11 §6.2.2.7.
  """

  use HidParser.ReportDescriptor.Item, decoder: :parse_signed
end
