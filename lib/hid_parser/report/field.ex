defmodule HidParser.Report.Field do
  @moduledoc """
  A single field of a compiled HID report.

  A field is the product of one `Input`/`Output`/`Feature` main item after the
  parser has resolved the current global/local state, collection nesting and
  usage inheritance. See `HidParser.Report.compile/2`.

  ## Value storage

  The *canonical* value of a field is a list of logical integers (one per
  element, `count` of them). Physical and SI-scaled values are deliberately
  **not** stored: they are derived on demand by
  `HidParser.Report.physical/2` and `HidParser.Report.scaled/2`, so the model
  stays lossless and `build(parse(bin)) == bin` holds exactly.

  ## Usages

  Usage identity is `{usage_page, usage_id}`. `usage_page` is shared by every
  element of the field (it is a global item), while `usages` holds the ids:

    * a single `Usage` → `[id]` (the one id applies to all `count` elements),
    * `UsageMinimum`/`UsageMaximum` on a **variable** field → expanded to
      `count` per-element ids,
    * `UsageMinimum`/`UsageMaximum` on an **array** field → the full
      `min..max` range, i.e. the domain of values each element may take,
    * no local usage → inherited from the nearest enclosing collection that
      declares one (an empty list when none does).

  See HID 1.11 §6.2.2.7 and §6.2.2.8.
  """

  @type usage :: {usage_page :: integer(), usage_ids :: [integer()]}

  @type t :: %__MODULE__{
          type: :input | :output | :feature,
          report_id: integer(),
          offset: non_neg_integer(),
          size: pos_integer(),
          count: pos_integer(),
          signed?: boolean(),
          flags: map(),
          logical_min: integer(),
          logical_max: integer(),
          physical_min: integer() | nil,
          physical_max: integer() | nil,
          unit: map() | nil,
          unit_exponent: integer(),
          usage_page: integer(),
          usages: [integer()]
        }

  defstruct type: nil,
            report_id: 0,
            offset: 0,
            size: 0,
            count: 1,
            signed?: false,
            flags: %{},
            logical_min: 0,
            logical_max: 0,
            physical_min: nil,
            physical_max: nil,
            unit: nil,
            unit_exponent: 0,
            usage_page: 0,
            usages: []
end
