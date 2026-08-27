defmodule HidParser.ReportDescriptor.UnitExponent do
  # Global

  @type t :: %__MODULE__{value: integer()}

  defstruct value: 0

  def new(data) when is_binary(data) do
    %__MODULE__{value: HidParser.ReportDescriptor.Helper.parse_unit_exponent(data)}
  end
end
