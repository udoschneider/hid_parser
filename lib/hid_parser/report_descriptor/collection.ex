defmodule HidParser.ReportDescriptor.Collection do
  # Main

  @type t :: %__MODULE__{flags: integer(), items: list(), end_flags: integer()}

  defstruct flags: 0, items: [], end_flags: 0

  def new(data) when is_binary(data) do
    %__MODULE__{flags: HidParser.ReportDescriptor.Helper.parse_unsigned(data)}
  end
end
