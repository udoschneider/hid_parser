defmodule HidParser.Report do
  @moduledoc """
  A parsed HID report: the values of one report, tied to its report id.

  Produced by `HidParser.ReportCodec.decode/2` and consumed by
  `HidParser.ReportCodec.encode/2`. The `values` list is ordered (field order,
  element order) and lossless — one `HidParser.Report.Value` per element.
  Constant fields never appear; they are descriptor-driven and roundtrip as zero
  bits.
  """

  @type t :: %__MODULE__{report_id: integer(), values: [HidParser.Report.Value.t()]}

  defstruct report_id: 0, values: []
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
