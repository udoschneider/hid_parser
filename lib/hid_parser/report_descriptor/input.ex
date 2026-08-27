defmodule HidParser.ReportDescriptor.Input do
  @moduledoc """
  Main item: defines an input report field. See HID 1.11 §6.2.2.5.
  """

  use HidParser.ReportDescriptor.Item, field: :flags
end
