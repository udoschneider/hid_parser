defmodule HidParser.ReportDescriptor.EndCollection do
  @moduledoc """
  Main item: closes the most recently opened collection.

  Carries no data (`bSize` is always 0). See HID 1.11 §6.2.2.6.
  """

  @type t :: %__MODULE__{flags: integer()}

  defstruct flags: 0

  @doc """
  Builds an end-of-collection item (no data).
  """
  @spec new(binary()) :: t()
  def new(<<>>) do
    %__MODULE__{}
  end
end
