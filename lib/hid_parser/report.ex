defmodule HidParser.Report do
  @moduledoc """
  A parsed HID report: the values of one report, tied to its report type and id.

  Produced by `HidParser.ReportCodec.decode/3` and consumed by
  `HidParser.ReportCodec.encode/2`. The `values` list is ordered (field order,
  element order) and lossless — one `HidParser.Report.Value` per element.
  Constant fields never appear; they are descriptor-driven and roundtrip as zero
  bits.

  `type` selects the report stream (`:input`, `:output`, `:feature`) — the three
  are independent bit streams, each with its own report-id space.
  """

  @type t :: %__MODULE__{
          type: :input | :output | :feature,
          report_id: integer(),
          values: [HidParser.Report.Value.t()]
        }

  defstruct type: :input, report_id: 0, values: []
end

defimpl Inspect, for: HidParser.Report do
  import Inspect.Algebra

  def inspect(report, opts) do
    if opts.custom_options[:verbose] do
      Inspect.Any.inspect(report, opts)
    else
      concat([
        "#Report<",
        to_doc(report.report_id, opts),
        ", ",
        to_doc(report.values, opts),
        ">"
      ])
    end
  end
end
