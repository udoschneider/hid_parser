defmodule HidParser.ReportDescriptor.Output do
  @moduledoc """
  Main item: defines an output report field. See HID 1.11 §6.2.2.5.
  """

  use HidParser.ReportDescriptor.Item, field: :flags
end
