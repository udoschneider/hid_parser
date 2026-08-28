defmodule HidParser.ReportDescriptor.Pop do
  @moduledoc """
  Global item: restores the global item state from the stack.

  Carries no data. See HID 1.11 §6.2.2.7.
  """

  @type t :: %__MODULE__{}

  defstruct []

  @doc """
  Builds a pop item (no data).
  """
  @spec new(binary()) :: t()
  def new(<<>>), do: %__MODULE__{}
end
