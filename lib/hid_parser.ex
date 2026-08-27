defmodule HidParser do
  @moduledoc """
  A USB HID report descriptor parser and codec.

  The pipeline has three stages — parse the descriptor syntax, compile it into a
  codec, then decode/encode reports:

      {:ok, descriptor} = HidParser.ReportDescriptor.parse(descriptor_bytes)
      {:ok, codec}      = HidParser.ReportCodec.compile(descriptor, vid: vid, pid: pid)
      {:ok, report}     = HidParser.ReportCodec.decode(codec, report_bytes)
      {:ok, binary}     = HidParser.ReportCodec.encode(codec, report)

  See `HidParser.ReportDescriptor` (syntax), `HidParser.ReportCodec` (compiled
  model), and `HidParser.Report` (report data) for the individual stages. All
  four verbs return `{:ok, _}` / `{:error, %HidParser.Error{}}`.
  """
end
