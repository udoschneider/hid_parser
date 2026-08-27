defmodule HidParser.ReportDescriptor.Collection do
  @moduledoc """
  Main item: opens a collection that groups related items.

  Collections nest; `EndCollection` closes the most recent one. The collection
  type (application, physical, logical, ...) is carried in `flags`. See
  HID 1.11 §6.2.2.6.
  """

  @type t :: %__MODULE__{flags: integer(), items: list(), end_flags: integer()}

  defstruct flags: 0, items: [], end_flags: 0

  @doc """
  Builds a collection from the item's data bytes (the collection type).
  """
  def new(data) when is_binary(data) do
    %__MODULE__{flags: HidParser.ReportDescriptor.Helper.parse_unsigned(data)}
  end
end
