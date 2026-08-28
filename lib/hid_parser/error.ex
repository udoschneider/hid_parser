defmodule HidParser.Error do
  @moduledoc """
  A structured error returned by the report-model pipeline.

  `HidParser.ReportDescriptor.parse/1`, `HidParser.ReportCodec.compile/2`,
  `HidParser.ReportCodec.decode/3` and `HidParser.ReportCodec.encode/2` return
  `{:error, %HidParser.Error{}}` rather than raising, so callers match on
  `reason` and inspect the associated `detail`. It implements `Exception`, so it
  can also be `raise`d when that fits a caller's control flow.

  ## Reasons

    * `:invalid_descriptor` — descriptor bytes are malformed/truncated.
    * `:pop_without_push` — a `Pop` with no matching `Push` (compile).
    * `:push_without_pop` — a `Push` never popped (compile).
    * `:empty_report` — empty binary with a report-id descriptor (decode).
    * `:invalid_report` — report bytes are not a binary (decode).
    * `:report_size_mismatch` — report bytes are shorter/longer than the field layout; `detail` is `{expected_bytes, actual_bytes}` (decode).
    * `:unknown_report_id` — report id not in the codec; `detail` is the id.
    * `:field_mismatch` — a value references a field not in the report; `detail` is the field.
    * `:missing_values` — a non-constant field has no values; `detail` is the field.
    * `:value_count_mismatch` — wrong number of values for a field; `detail` is `{field, count}`.
    * `:out_of_range` — a logical value outside the field's range; `detail` is `{field, value}`.
  """

  @type reason ::
          :invalid_descriptor
          | :pop_without_push
          | :push_without_pop
          | :empty_report
          | :invalid_report
          | :report_size_mismatch
          | :unknown_report_id
          | :field_mismatch
          | :missing_values
          | :value_count_mismatch
          | :out_of_range

  @type t :: %__MODULE__{reason: reason(), detail: term()}

  defexception [:reason, :detail]

  @impl Exception
  def message(%__MODULE__{reason: reason, detail: nil}), do: to_string(reason)

  def message(%__MODULE__{reason: reason, detail: detail}) do
    "#{reason}: #{inspect(detail)}"
  end
end

defimpl Inspect, for: HidParser.Error do
  import Inspect.Algebra

  def inspect(error, opts) do
    if opts.custom_options[:verbose] do
      Inspect.Any.inspect(error, opts)
    else
      reason = to_string(error.reason)

      case error.detail do
        nil -> concat(["#Error<", reason, ">"])
        detail -> concat(["#Error<", reason, ", ", to_doc(detail, opts), ">"])
      end
    end
  end
end
