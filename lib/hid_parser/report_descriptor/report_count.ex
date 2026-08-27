defmodule HidParser.ReportDescriptor.ReportCount do
  # Global

  @type t :: %__MODULE__{value: integer()}

  defstruct value: 0

  def new(data) when is_binary(data) do
    %__MODULE__{value: HidParser.Helper.parse_unsigned(data)}
  end
end
