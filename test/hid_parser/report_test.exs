defmodule HidParser.ReportTest do
  use ExUnit.Case

  alias HidParser.Report
  alias HidParser.Report.Field

  doctest HidParser.Report

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

  describe "compile/2" do
    test "compiles a keyboard into per-report fields" do
      report = Report.compile(@keyboard)

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

      report = Report.compile(descriptor)

      assert report.uses_report_id? == false
      assert [field] = report.reports[0]
      assert field.report_id == 0
      assert %Field{size: 1, count: 3, usages: [0x30]} = field
    end

    test "report_id option keys a report-id-less descriptor" do
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

      report = Report.compile(descriptor, report_id: 3)

      assert report.uses_report_id? == false
      assert [field] = report.reports[3]
      assert field.report_id == 3
    end

    test "stores vid/pid metadata" do
      descriptor =
        <<0x05, 0x01, 0x09, 0x30, 0x15, 0x00, 0x25, 0x01, 0x75, 0x08, 0x95, 0x01, 0x81, 0x02>>

      report = Report.compile(descriptor, vid: 0x046A, pid: 0x00B0)

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

      [field] = Report.compile(descriptor).reports[0]

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

      [field] = Report.compile(descriptor).reports[0]

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

      report = Report.compile(descriptor)

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

      [field] = Report.compile(descriptor).reports[0]

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

      [first, second] = Report.compile(descriptor).reports[0]

      assert %Field{size: 16, count: 1, usages: [0x30]} = first
      assert %Field{size: 8, count: 1, usages: [0x31]} = second
    end

    test "raises on unbalanced Pop" do
      assert_raise ArgumentError, ~r/Pop without a matching Push/, fn ->
        Report.compile(<<0xB4>>)
      end
    end

    test "raises on unclosed collection" do
      assert_raise ArgumentError, ~r/EndCollection missing/, fn ->
        Report.compile(<<0x05, 0x01, 0x09, 0x01, 0xA1, 0x00>>)
      end
    end
  end

  describe "parse/2 + build/2 roundtrip" do
    test "keyboard with report id, array and constant padding" do
      report = Report.compile(@keyboard)
      [modifiers, _padding, keys] = report.reports[1]

      values = [{modifiers, [1, 0, 1, 0, 0, 0, 0, 0]}, {keys, [0x04, 0x1E, 0, 0, 0, 0]}]

      assert {:ok, binary} = Report.build(report, values)
      assert binary == <<1, 0x05, 0x00, 0x04, 0x1E, 0, 0, 0, 0>>

      assert {:ok, ^values} = Report.parse(report, binary)
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

      report = Report.compile(descriptor)
      [field] = report.reports[0]

      for v <- [-32_768, -1, 0, 1, 32_767] do
        values = [{field, [v]}]
        assert {:ok, binary} = Report.build(report, values)
        assert {:ok, ^values} = Report.parse(report, binary)
      end
    end

    test "build(parse(bin)) == bin for constant-free reports" do
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

      report = Report.compile(descriptor)
      [field] = report.reports[0]

      for v <- [-32_768, -1, 0, 1, 32_767] do
        assert {:ok, binary} = Report.build(report, [{field, [v]}])
        assert {:ok, values} = Report.parse(report, binary)
        assert {:ok, ^binary} = Report.build(report, values)
      end
    end

    test "build(parse(bin)) == bin with zero constant padding" do
      report = Report.compile(@keyboard)

      # Constant padding must be zero for an exact roundtrip (documented corner).
      binary = <<1, 0x05, 0x00, 0x04, 0x1E, 0, 0, 0, 0>>

      assert {:ok, values} = Report.parse(report, binary)
      assert {:ok, ^binary} = Report.build(report, values)
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

      report = Report.compile(descriptor)
      [f1] = report.reports[1]
      [f2] = report.reports[2]

      assert {:ok, <<1, 0x01>>} = Report.build(report, [{f1, [0x01]}])
      assert {:ok, <<2, 0xAA, 0xBB>>} = Report.build(report, [{f2, [0xAA, 0xBB]}])

      assert {:ok, [{^f1, [0x01]}]} = Report.parse(report, <<1, 0x01>>)
      assert {:ok, [{^f2, [0xAA, 0xBB]}]} = Report.parse(report, <<2, 0xAA, 0xBB>>)
    end

    test "parse errors on empty report with report ids" do
      report = Report.compile(@keyboard)

      assert Report.parse(report, <<>>) == {:error, :empty_report}
    end

    test "parse errors on unknown report id" do
      report = Report.compile(@keyboard)

      assert Report.parse(report, <<0x02, 0x00, 0x00>>) == {:error, {:unknown_report_id, 2}}
    end

    test "build errors on out-of-range value" do
      report = Report.compile(@keyboard)
      [modifiers, _padding, keys] = report.reports[1]

      assert {:error, {:out_of_range, ^modifiers, 5}} =
               Report.build(report, [
                 {modifiers, [1, 0, 1, 0, 0, 0, 0, 5]},
                 {keys, [0, 0, 0, 0, 0, 0]}
               ])
    end

    test "build errors on wrong number of values" do
      report = Report.compile(@keyboard)
      [modifiers, _padding, keys] = report.reports[1]

      assert {:error, {:value_count_mismatch, ^modifiers, 2}} =
               Report.build(report, [{modifiers, [1, 0]}, {keys, [0, 0, 0, 0, 0, 0]}])
    end

    test "build errors on missing values" do
      report = Report.compile(@keyboard)
      [modifiers, _padding, keys] = report.reports[1]

      assert {:error, {:missing_values, ^keys}} =
               Report.build(report, [{modifiers, [0, 0, 0, 0, 0, 0, 0, 0]}])
    end

    test "build errors on extra values" do
      report = Report.compile(@keyboard)
      [modifiers, _padding, keys] = report.reports[1]

      values = [
        {modifiers, [0, 0, 0, 0, 0, 0, 0, 0]},
        {keys, [0, 0, 0, 0, 0, 0]},
        {modifiers, [0, 0, 0, 0, 0, 0, 0, 0]}
      ]

      assert {:error, {:extra_values, _}} = Report.build(report, values)
    end
  end

  describe "value accessors" do
    test "value/2 is the identity" do
      assert Report.value(%Field{}, 42) == 42
    end

    test "physical/2 linear mapping" do
      field = %Field{logical_min: 0, logical_max: 100, physical_min: 0, physical_max: 1000}

      assert Report.physical(field, 50) == 500.0
    end

    test "physical/2 is nil without a physical range" do
      field = %Field{logical_min: 0, logical_max: 100}

      assert Report.physical(field, 50) == nil
    end

    test "physical/2 is nil on degenerate logical range" do
      field = %Field{logical_min: 0, logical_max: 0, physical_min: 0, physical_max: 100}

      assert Report.physical(field, 0) == nil
    end

    test "scaled/2 applies the unit exponent" do
      field = %Field{
        logical_min: 0,
        logical_max: 100,
        physical_min: 0,
        physical_max: 1000,
        unit_exponent: -1
      }

      assert Report.scaled(field, 50) == 50.0
    end

    test "scaled/2 is nil when physical/2 is nil" do
      assert Report.scaled(%Field{logical_min: 0, logical_max: 100}, 50) == nil
    end
  end

  describe "to_keyword/2" do
    test "flattens one entry per element" do
      report = Report.compile(@keyboard)
      [modifiers, _padding, keys] = report.reports[1]

      values = [{modifiers, [1, 0]}, {keys, [0x04, 0x1E]}]

      assert Report.to_keyword(report, values) == [
               {"Keyboard LeftControl", %{usage_page: 7, usage_id: 0xE0, value: 1}},
               {"Keyboard LeftShift", %{usage_page: 7, usage_id: 0xE1, value: 0}},
               {"Keyboard A", %{usage_page: 7, usage_id: 0x04, value: 0x04}},
               {"Keyboard 1 and Bang", %{usage_page: 7, usage_id: 0x1E, value: 0x1E}}
             ]
    end

    test "a shared usage is repeated for every element" do
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
        0x02,
        0x81,
        0x02
      >>

      report = Report.compile(descriptor)
      [field] = report.reports[0]

      assert Report.to_keyword(report, [{field, [1, 0]}]) == [
               {"X", %{usage_page: 1, usage_id: 0x30, value: 1}},
               {"X", %{usage_page: 1, usage_id: 0x30, value: 0}}
             ]
    end
  end
end
