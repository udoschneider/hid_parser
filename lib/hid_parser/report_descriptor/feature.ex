defmodule HidParser.ReportDescriptor.Feature do
  # Main

  @type t :: %__MODULE__{flags: integer()}

  defstruct flags: 0

  def new(data) when is_binary(data) do
    %__MODULE__{flags: HidParser.Helper.parse_unsigned(data)}
  end
end
