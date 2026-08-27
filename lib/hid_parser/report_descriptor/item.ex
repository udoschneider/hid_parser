defmodule HidParser.ReportDescriptor.Item do
  @moduledoc """
  Defines the struct and `new/1` constructor shared by report descriptor items.

  Every item type maps to a struct with a single `value` (global/local items)
  or `flags` (main items) field, decoded from the item's data bytes by one of
  the `HidParser.ReportDescriptor.Helper` decoders. This macro generates that
  common shape so each item module only declares what differs.

  Options:
    * `:field` — struct field name, `:value` (default) or `:flags`
    * `:decoder` — decoder function, `:parse_unsigned` (default),
      `:parse_signed`, or `:parse_unit_exponent`

  Items that don't fit this shape (`Collection`, `EndCollection`, `Reserved`,
  `Push`, `Pop`) define their own struct and `new/1`.
  """

  @doc false
  defmacro __using__(opts) do
    decoder = Keyword.get(opts, :decoder, :parse_unsigned)

    case Keyword.get(opts, :field, :value) do
      :value ->
        quote do
          @type t :: %__MODULE__{value: integer()}

          defstruct value: 0

          def new(data) when is_binary(data) do
            %__MODULE__{
              value: apply(HidParser.ReportDescriptor.Helper, unquote(decoder), [data])
            }
          end
        end

      :flags ->
        quote do
          @type t :: %__MODULE__{flags: integer()}

          defstruct flags: 0

          def new(data) when is_binary(data) do
            %__MODULE__{
              flags: apply(HidParser.ReportDescriptor.Helper, unquote(decoder), [data])
            }
          end
        end
    end
  end
end
