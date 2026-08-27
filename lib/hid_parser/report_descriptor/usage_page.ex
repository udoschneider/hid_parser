defmodule HidParser.ReportDescriptor.UsagePage do
  @moduledoc """
  Global item: sets the usage page that subsequent local Usage items refer to; persists until changed. See HID 1.11 §6.2.2.7.
  """

  use HidParser.ReportDescriptor.Item
end
