defmodule HidParser.ReportDescriptor.Feature do
  @moduledoc """
  Main item: defines a feature report field. See HID 1.11 §6.2.2.5.
  """

  use HidParser.ReportDescriptor.Item, field: :flags
end
