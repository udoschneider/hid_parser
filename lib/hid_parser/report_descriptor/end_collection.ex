defmodule HidParser.ReportDescriptor.EndCollection do
  # Main

  @type t :: %__MODULE__{flags: integer()}

  defstruct flags: 0

  def new(<<>>) do
    %__MODULE__{}
  end
end
