defmodule HidParser.ReportDescriptor.UnitExponent do
  @moduledoc """
  Global item: the exponent applied to the Unit value. See HID 1.11 §6.2.2.7.
  """

  use HidParser.ReportDescriptor.Item, decoder: :parse_unit_exponent
end
