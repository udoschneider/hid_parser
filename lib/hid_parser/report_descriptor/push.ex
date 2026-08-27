defmodule HidParser.ReportDescriptor.Push do
  @moduledoc """
  Global item: pushes the global item state onto a stack.

  Carries no data. See HID 1.11 §6.2.2.7.
  """

  @type t :: %__MODULE__{}

  defstruct []

  @doc """
  Builds a push item (no data).
  """
  def new(data) when is_binary(data), do: %__MODULE__{}
end
