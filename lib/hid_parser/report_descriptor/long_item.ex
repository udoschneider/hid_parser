defmodule HidParser.ReportDescriptor.LongItem do
  @moduledoc """
  A long item: a vendor-defined item with an 8-bit tag and arbitrary data.

  Long items are the extension mechanism of the report descriptor format
  (HID 1.11 §6.2.2.3); their tag and data are opaque to this parser.
  """

  @type t :: %__MODULE__{tag: integer(), data: binary()}

  defstruct tag: 0, data: <<>>

  @doc """
  Builds a long item from its tag and data bytes.
  """
  def new(tag, data) when is_integer(tag) and is_binary(data) do
    %__MODULE__{tag: tag, data: data}
  end
end
