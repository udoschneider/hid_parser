defmodule HidParser.ReportDescriptor.Reserved do
  @moduledoc """
  Represents an item whose tag is not defined.

  Preserves the raw bytes so descriptors with unknown items can still be
  consumed (forward compatibility). See HID 1.11 §6.2.2.1.
  """

  @type t :: %__MODULE__{raw: binary()}

  defstruct raw: <<>>

  @doc """
  Builds a reserved item from its raw bytes.
  """
  @spec new(binary()) :: t()
  def new(raw) when is_binary(raw) do
    %__MODULE__{raw: raw}
  end
end
