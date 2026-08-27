defmodule HidParser.ReportTest do
  use ExUnit.Case

  alias HidParser.Error
  alias HidParser.Report
  alias HidParser.Report.Value
  alias HidParser.ReportCodec
  alias HidParser.ReportCodec.Field

  doctest HidParser.Report.Value

  @keyboard <<
    0x05,
    0x01,
    0x09,
    0x06,
    0xA1,
    0x01,
    0x85,
    0x01,
    0x05,
    0x07,
    0x19,
    0xE0,
    0x29,
    0xE7,
    0x15,
    0x00,
    0x25,
    0x01,
    0x75,
    0x01,
    0x95,
    0x08,
    0x81,
    0x02,
    0x95,
    0x01,
    0x75,
    0x08,
    0x81,
    0x01,
    0x95,
    0x06,
    0x75,
    0x08,
    0x15,
    0x00,
    0x25,
    0x65,
    0x05,
    0x07,
    0x19,
    0x00,
    0x29,
    0x65,
    0x81,
    0x00,
    0xC0
  >>

  defp codec(bytes, opts \\ []) do
    {:ok, descriptor} = HidParser.ReportDescriptor.parse(bytes)
    {:ok, codec} = HidParser.ReportCodec.compile(descriptor, opts)
    codec
  end

  defp values(field, ints) do
    ints
    |> Enum.with_index()
    |> Enum.map(fn {logical, index} -> %Value{field: field, index: index, logical: logical} end)
  end

  describe "compile/2" do
    test "compiles a keyboard into per-report fields" do
      report = codec(@keyboard)

      assert report.vid == nil
      assert report.pid == nil
      assert report.uses_report_id? == true
      assert Map.keys(report.reports) == [1]

      [modifiers, padding, keys] = report.reports[1]

      assert %Field{
               type: :input,
               report_id: 1,
               offset: 0,
               size: 1,
               count: 8,
               signed?: false,
               flags: %{constant: false, variable: true},
               logical_min: 0,
               logical_max: 1,
               usage_page: 7,
               usages: [0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7]
             } = modifiers

      assert %Field{offset: 8, size: 8, count: 1, flags: %{constant: true}} = padding

      assert %Field{
               offset: 16,
               size: 8,
               count: 6,
               flags: %{variable: false},
               logical_min: 0,
               logical_max: 101,
               usage_page: 7,
               usages: usages
             } = keys

      assert usages == Enum.to_list(0..101)
    end

    test "descriptor without report id maps to report_id 0" do
      descriptor = <<
        0x05,
        0x01,
        0x09,
        0x30,
        0x15,
        0x00,
        0x25,
        0x01,
        0x75,
        0x01,
        0x95,
        0x03,
        0x81,
        0x02
      >>

      report = codec(descriptor)

      assert report.uses_report_id? == false
      assert [field] = report.reports[0]
      assert field.report_id == 0
      assert %Field{size: 1, count: 3, usages: [0x30]} = field
    end

    test "stores vid/pid metadata" do
      descriptor = <<
        0x05,
        0x01,
        0x09,
        0x30,
        0x15,
        0x00,
        0x25,
        0x01,
        0x75,
        0x08,
        0x95,
        0x01,
        0x81,
        0x02
      >>

      report = codec(descriptor, vid: 0x046A, pid: 0x00B0)

      assert report.vid == 0x046A
      assert report.pid == 0x00B0
    end

    test "signed field when logical_min < 0" do
      descriptor = <<
        0x05,
        0x01,
        0x09,
        0x30,
        0x16,
        0x00,
        0x80,
        0x26,
        0xFF,
        0x7F,
        0x75,
        0x10,
        0x95,
        0x01,
        0x81,
        0x02
      >>

      [field] = codec(descriptor).reports[0]

      assert field.signed? == true
      assert field.logical_min == -32_768
      assert field.logical_max == 32_767
    end

    test "physical range and unit are recorded" do
      descriptor = <<
        0x05,
        0x01,
        0x09,
        0x30,
        0x15,
        0x00,
        0x26,
        0xFF,
        0x0F,
        0x35,
        0x00,
        0x46,
        0x00,
        0x28,
        0x65,
        0x11,
        0x55,
        0x0F,
        0x75,
        0x10,
        0x95,
        0x01,
        0x81,
        0x02
      >>

      [field] = codec(descriptor).reports[0]

      assert field.physical_min == 0
      assert field.physical_max == 10_240
      assert field.unit_exponent == -1
      assert field.unit.system == :si_linear
      assert field.unit.length == 1
    end

    test "multi report id descriptor" do
      descriptor = <<
        0x05,
        0x01,
        0x85,
        0x01,
        0x09,
        0x30,
        0x15,
        0x00,
        0x25,
        0x01,
        0x75,
        0x08,
        0x95,
        0x01,
        0x81,
        0x02,
        0x85,
        0x02,
        0x09,
        0x31,
        0x15,
        0x00,
        0x26,
        0xFF,
        0x00,
        0x75,
        0x08,
        0x95,
        0x02,
        0x81,
        0x02
      >>

      report = codec(descriptor)

      assert Map.keys(report.reports) == [1, 2]

      assert [%Field{report_id: 1, count: 1, usages: [0x30]}] = report.reports[1]
      assert [%Field{report_id: 2, count: 2, usages: [0x31]}] = report.reports[2]
    end

    test "collection usage is inherited by fields that declare none" do
      descriptor = <<
        0x05,
        0x01,
        0x09,
        0x30,
        0xA1,
        0x00,
        0x15,
        0x00,
        0x25,
        0x01,
        0x75,
        0x01,
        0x95,
        0x01,
        0x81,
        0x02,
        0xC0
      >>

      [field] = codec(descriptor).reports[0]

      assert field.usage_page == 1
      assert field.usages == [0x30]
    end

    test "Push/Pop restores global state" do
      descriptor = <<
        0x75,
        0x08,
        0x95,
        0x01,
        0xA4,
        0x75,
        0x10,
        0x09,
        0x30,
        0x15,
        0x00,
        0x25,
        0xFF,
        0x81,
        0x02,
        0xB4,
        0x09,
        0x31,
        0x15,
        0x00,
        0x25,
        0x01,
        0x81,
        0x02
      >>

      [first, second] = codec(descriptor).reports[0]

      assert %Field{size: 16, count: 1, usages: [0x30]} = first
      assert %Field{size: 8, count: 1, usages: [0x31]} = second
    end

    test "errors on Pop without Push" do
      assert {:error, %Error{reason: :pop_without_push}} = codec_error(<<0xB4>>)
    end

    test "errors on Push without Pop" do
      assert {:error, %Error{reason: :push_without_pop}} = codec_error(<<0xA4>>)
    end
  end

  describe "decode/2 + encode/2 roundtrip" do
    test "keyboard with report id, array and constant padding" do
      codec = codec(@keyboard)
      [modifiers, _padding, keys] = codec.reports[1]

      values =
        values(modifiers, [1, 0, 1, 0, 0, 0, 0, 0]) ++ values(keys, [0x04, 0x1E, 0, 0, 0, 0])

      report = %Report{report_id: 1, values: values}

      assert {:ok, binary} = ReportCodec.encode(codec, report)
      assert binary == <<1, 0x05, 0x00, 0x04, 0x1E, 0, 0, 0, 0>>

      assert {:ok, ^report} = ReportCodec.decode(codec, binary)
    end

    test "signed 16-bit field roundtrips its full range" do
      descriptor = <<
        0x05,
        0x01,
        0x09,
        0x30,
        0x16,
        0x00,
        0x80,
        0x26,
        0xFF,
        0x7F,
        0x75,
        0x10,
        0x95,
        0x01,
        0x81,
        0x02
      >>

      codec = codec(descriptor)
      [field] = codec.reports[0]

      for v <- [-32_768, -1, 0, 1, 32_767] do
        report = %Report{report_id: 0, values: values(field, [v])}
        assert {:ok, binary} = ReportCodec.encode(codec, report)
        assert {:ok, ^report} = ReportCodec.decode(codec, binary)
      end
    end

    test "encode(decode(bin)) == bin for constant-free reports" do
      descriptor = <<
        0x05,
        0x01,
        0x09,
        0x30,
        0x16,
        0x00,
        0x80,
        0x26,
        0xFF,
        0x7F,
        0x75,
        0x10,
        0x95,
        0x01,
        0x81,
        0x02
      >>

      codec = codec(descriptor)
      [field] = codec.reports[0]

      for v <- [-32_768, -1, 0, 1, 32_767] do
        assert {:ok, binary} =
                 ReportCodec.encode(codec, %Report{report_id: 0, values: values(field, [v])})

        assert {:ok, report} = ReportCodec.decode(codec, binary)
        assert {:ok, ^binary} = ReportCodec.encode(codec, report)
      end
    end

    test "encode(decode(bin)) == bin with zero constant padding" do
      codec = codec(@keyboard)

      binary = <<1, 0x05, 0x00, 0x04, 0x1E, 0, 0, 0, 0>>

      assert {:ok, report} = ReportCodec.decode(codec, binary)
      assert {:ok, ^binary} = ReportCodec.encode(codec, report)
    end

    test "multi report id roundtrip" do
      descriptor = <<
        0x05,
        0x01,
        0x85,
        0x01,
        0x09,
        0x30,
        0x15,
        0x00,
        0x25,
        0x01,
        0x75,
        0x08,
        0x95,
        0x01,
        0x81,
        0x02,
        0x85,
        0x02,
        0x09,
        0x31,
        0x15,
        0x00,
        0x26,
        0xFF,
        0x00,
        0x75,
        0x08,
        0x95,
        0x02,
        0x81,
        0x02
      >>

      codec = codec(descriptor)
      [f1] = codec.reports[1]
      [f2] = codec.reports[2]

      r1 = %Report{report_id: 1, values: values(f1, [1])}
      r2 = %Report{report_id: 2, values: values(f2, [0xAA, 0xBB])}

      assert {:ok, <<1, 0x01>>} = ReportCodec.encode(codec, r1)
      assert {:ok, <<2, 0xAA, 0xBB>>} = ReportCodec.encode(codec, r2)

      assert {:ok, ^r1} = ReportCodec.decode(codec, <<1, 0x01>>)
      assert {:ok, ^r2} = ReportCodec.decode(codec, <<2, 0xAA, 0xBB>>)
    end

    test "decode errors on empty report with report ids" do
      codec = codec(@keyboard)

      assert ReportCodec.decode(codec, <<>>) == {:error, %Error{reason: :empty_report}}
    end

    test "decode errors on unknown report id" do
      codec = codec(@keyboard)

      assert ReportCodec.decode(codec, <<0x02, 0x00, 0x00>>) ==
               {:error, %Error{reason: :unknown_report_id, detail: 2}}
    end

    test "decode errors on a codec with no reports" do
      codec = codec(<<0x05, 0x01>>)

      assert ReportCodec.decode(codec, <<>>) == {:error, %Error{reason: :no_reports}}
    end
  end

  describe "encode/2 errors" do
    test "unknown report id" do
      codec = codec(@keyboard)

      assert ReportCodec.encode(codec, %Report{report_id: 2, values: []}) ==
               {:error, %Error{reason: :unknown_report_id, detail: 2}}
    end

    test "out-of-range value" do
      codec = codec(@keyboard)
      [modifiers, _padding, keys] = codec.reports[1]

      report = %Report{
        report_id: 1,
        values: values(modifiers, [1, 0, 1, 0, 0, 0, 0, 5]) ++ values(keys, [0, 0, 0, 0, 0, 0])
      }

      assert {:error, %Error{reason: :out_of_range, detail: {^modifiers, 5}}} =
               ReportCodec.encode(codec, report)
    end

    test "value count mismatch" do
      codec = codec(@keyboard)
      [modifiers, _padding, keys] = codec.reports[1]

      report = %Report{
        report_id: 1,
        values: values(modifiers, [1, 0]) ++ values(keys, [0, 0, 0, 0, 0, 0])
      }

      assert {:error, %Error{reason: :value_count_mismatch, detail: {^modifiers, 2}}} =
               ReportCodec.encode(codec, report)
    end

    test "missing values" do
      codec = codec(@keyboard)
      [modifiers, _padding, keys] = codec.reports[1]

      report = %Report{report_id: 1, values: values(modifiers, [0, 0, 0, 0, 0, 0, 0, 0])}

      assert {:error, %Error{reason: :missing_values, detail: ^keys}} =
               ReportCodec.encode(codec, report)
    end

    test "field mismatch" do
      codec = codec(@keyboard)
      bogus = %Field{offset: 999}

      report = %Report{report_id: 1, values: [%Value{field: bogus, index: 0, logical: 0}]}

      assert {:error, %Error{reason: :field_mismatch, detail: ^bogus}} =
               ReportCodec.encode(codec, report)
    end
  end

  describe "Value accessors" do
    test "logical/1 is the stored integer" do
      field = %Field{}
      assert Value.logical(%Value{field: field, index: 0, logical: 42}) == 42
    end

    test "physical/1 linear mapping" do
      field = %Field{logical_min: 0, logical_max: 100, physical_min: 0, physical_max: 1000}
      value = %Value{field: field, index: 0, logical: 50}

      assert Value.physical(value) == 500.0
    end

    test "physical/1 is nil without a physical range" do
      field = %Field{logical_min: 0, logical_max: 100}
      value = %Value{field: field, index: 0, logical: 50}

      assert Value.physical(value) == nil
    end

    test "physical/1 is nil on degenerate logical range" do
      field = %Field{logical_min: 0, logical_max: 0, physical_min: 0, physical_max: 100}
      value = %Value{field: field, index: 0, logical: 0}

      assert Value.physical(value) == nil
    end

    test "scaled/1 applies the unit exponent" do
      field = %Field{
        logical_min: 0,
        logical_max: 100,
        physical_min: 0,
        physical_max: 1000,
        unit_exponent: -1
      }

      value = %Value{field: field, index: 0, logical: 50}

      assert Value.scaled(value) == 50.0
    end

    test "scaled/1 is nil when physical/1 is nil" do
      field = %Field{logical_min: 0, logical_max: 100}
      value = %Value{field: field, index: 0, logical: 50}

      assert Value.scaled(value) == nil
    end

    test "usage/1 and name/1" do
      field = %Field{usage_page: 1, usages: [0x30], flags: %{variable: true}}
      value = %Value{field: field, index: 0, logical: -3}

      assert Value.usage(value) == {1, 0x30}
      assert Value.name(value) == "X"
    end

    test "name/1 falls back for unknown usages" do
      field = %Field{usage_page: 0xFFFF, usages: [0x30], flags: %{variable: true}}
      value = %Value{field: field, index: 0, logical: -3}

      assert Value.name(value) == "0xFFFF:0x30"
    end

    test "array element usage is its value" do
      field = %Field{usage_page: 7, usages: [0], flags: %{variable: false}}
      value = %Value{field: field, index: 0, logical: 0x04}

      assert Value.usage(value) == {7, 0x04}
      assert Value.name(value) == "Keyboard A"
    end
  end

  describe "inspect" do
    test "Value is concise" do
      field = %Field{usage_page: 7, usages: [0xE0], flags: %{variable: true}}
      value = %Value{field: field, index: 0, logical: 1}

      assert inspect(value) == "#Report.Value<Keyboard LeftControl = 1>"
    end

    test "Value is verbose with custom option" do
      field = %Field{usage_page: 7, usages: [0xE0], flags: %{variable: true}}
      value = %Value{field: field, index: 0, logical: 1}

      assert inspect(value, custom_options: [verbose: true]) =~ "%HidParser.Report.Value{"
    end

    test "Report is concise" do
      assert inspect(%Report{report_id: 1, values: []}) == "#Report<1, []>"
    end

    test "Error is concise" do
      assert inspect(%Error{reason: :out_of_range}) == "#Error<out_of_range>"
    end

    test "Codec and Descriptor are concise" do
      codec = codec(@keyboard)

      assert inspect(codec) == "#ReportCodec<vid: nil, pid: nil, 1 reports>"
      assert inspect(codec.reports[1] |> hd()) =~ "#Field<"
    end
  end

  defp codec_error(bytes) do
    {:ok, descriptor} = HidParser.ReportDescriptor.parse(bytes)
    HidParser.ReportCodec.compile(descriptor)
  end
end
