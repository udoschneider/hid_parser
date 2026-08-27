defmodule HidParser.ReportDescriptor.Reserved do
  # Main

  @type t :: %__MODULE__{raw: binary()}

  defstruct raw: <<>>

  def new(raw) when is_binary(raw) do
    %__MODULE__{raw: raw}
  end
end
