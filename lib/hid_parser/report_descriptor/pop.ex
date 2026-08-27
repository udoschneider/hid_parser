defmodule HidParser.ReportDescriptor.Pop do
  # Global

  @type t :: %__MODULE__{}

  defstruct []

  def new(data) when is_binary(data), do: %__MODULE__{}
end
