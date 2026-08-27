defmodule HidParser.ReportFixtureTest do
  use ExUnit.Case

  @moduletag :fixtures

  @fixtures_dir Path.expand("../fixtures", __DIR__)

  fixtures_present? =
    File.dir?(@fixtures_dir) and
      @fixtures_dir |> File.ls!() |> Enum.any?(&String.ends_with?(&1, ".py"))

  if not fixtures_present? do
    @moduletag skip: "fixtures not fetched (run `mix hid_parser.fetch_fixtures`)"
  end

  @descriptor_re ~r/report_descriptor\s*=\s*\[(.*?)\n\s*\]/s
  @comment_re ~r/#[^\n]*/
  @byte_re ~r/0x[0-9a-fA-F]+|0b[01]+|\d+/

  test "every fixture descriptor roundtrips" do
    descriptors = descriptors()

    refute descriptors == [], "no descriptors extracted from fixtures"

    for {file, index, descriptor} <- descriptors do
      report = HidParser.Report.compile(descriptor)

      for {id, fields} <- report.reports, roundtrippable?(fields) do
        values = values_for(fields)

        assert {:ok, binary} = HidParser.Report.build(report, values),
               "#{file}[#{index}] report #{id}: build failed"

        assert {:ok, ^values} = HidParser.Report.parse(report, binary),
               "#{file}[#{index}] report #{id}: roundtrip mismatch"
      end
    end
  end

  defp descriptors do
    @fixtures_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".py"))
    |> Enum.sort()
    |> Enum.flat_map(fn file ->
      Path.join(@fixtures_dir, file)
      |> File.read!()
      |> extract_descriptors()
      |> Enum.with_index()
      |> Enum.map(fn {bytes, index} -> {file, index, bytes} end)
    end)
  end

  defp extract_descriptors(source) do
    for [_, body] <- Regex.scan(@descriptor_re, source) do
      body
      |> String.replace(@comment_re, "")
      |> then(&Regex.scan(@byte_re, &1))
      |> Enum.map(fn [token] -> decode_token(token) end)
      |> IO.iodata_to_binary()
    end
  end

  defp decode_token("0x" <> hex), do: String.to_integer(hex, 16)
  defp decode_token("0b" <> bin), do: String.to_integer(bin, 2)
  defp decode_token(decimal), do: String.to_integer(decimal)

  defp roundtrippable?(fields) do
    Enum.any?(fields, &(not &1.flags.constant)) and
      Enum.all?(fields, &(&1.logical_min <= &1.logical_max))
  end

  defp values_for(fields) do
    for field <- fields, not field.flags.constant do
      range = field.logical_max - field.logical_min + 1

      values =
        for i <- 0..(field.count - 1), do: field.logical_min + rem(i, range)

      {field, values}
    end
  end
end
