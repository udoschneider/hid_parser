defmodule HidParser.ReportDescriptorTest do
  use ExUnit.Case
  alias HidParser.ReportDescriptor.{Output, Feature, Collection, EndCollection}

  alias HidParser.ReportDescriptor.{
    UsagePage,
    LogicalMinimum,
    LogicalMaximum,
    PhysicalMinimum,
    PhysicalMaximum,
    UnitExponent,
    Unit,
    ReportSize,
    ReportId,
    ReportCount,
    Push,
    Pop
  }

  alias HidParser.ReportDescriptor.{
    Usage,
    UsageMinimum,
    UsageMaximum,
    DesignatorIndex,
    DesignatorMinimum,
    DesignatorMaximum,
    StringIndex,
    StringMinimum,
    StringMaximum,
    Delimiter
  }

  doctest HidParser

  test "parse binary only" do
    assert_raise(FunctionClauseError, fn -> HidParser.parse_report_descriptor(:foo) end)
  end

  describe "Report main items" do
    test "output" do
      assert HidParser.parse_report_descriptor(<<0b1001_00_01, 0x01>>) == [%Output{flags: 1}]
    end

    test "feature" do
      assert HidParser.parse_report_descriptor(<<0b1011_00_01, 0x02>>) == [%Feature{flags: 2}]
    end

    test "collection" do
      assert HidParser.parse_report_descriptor(<<0b1010_00_01, 0x03>>) == [%Collection{flags: 3}]
    end

    test "end collection" do
      assert HidParser.parse_report_descriptor(<<0b1100_00_00>>) == [%EndCollection{flags: 0}]
    end
  end

  describe "Report global items" do
    test "usage page" do
      assert HidParser.parse_report_descriptor(<<0x05, 0x01>>) == [%UsagePage{value: 1}]
    end

    test "logical minimum" do
      assert HidParser.parse_report_descriptor(<<0x15, 0x00>>) == [%LogicalMinimum{value: 0}]
    end

    test "logical maximum" do
      assert HidParser.parse_report_descriptor(<<0x25, 0x01>>) == [%LogicalMaximum{value: 1}]
    end

    test "physical minimum" do
      assert HidParser.parse_report_descriptor(<<0x35, 0x00>>) == [%PhysicalMinimum{value: 0}]
    end

    test "physical maximum" do
      assert HidParser.parse_report_descriptor(<<0x45, 0x01>>) == [%PhysicalMaximum{value: 1}]
    end

    test "unit exponent" do
      assert HidParser.parse_report_descriptor(<<0x55, 0x01>>) == [%UnitExponent{value: 1}]
    end

    test "unit" do
      assert HidParser.parse_report_descriptor(<<0x65, 0x01>>) == [%Unit{value: 1}]
    end

    test "report size" do
      assert HidParser.parse_report_descriptor(<<0x75, 0x01>>) == [%ReportSize{value: 1}]
    end

    test "report ID" do
      assert HidParser.parse_report_descriptor(<<0x85, 0x01>>) == [%ReportId{value: 1}]
    end

    test "report count" do
      assert HidParser.parse_report_descriptor(<<0x95, 0x01>>) == [%ReportCount{value: 1}]
    end

    test "push" do
      assert HidParser.parse_report_descriptor(<<0xA4>>) == [%Push{}]
    end

    test "pop" do
      assert HidParser.parse_report_descriptor(<<0xB4>>) == [%Pop{}]
    end

    test "reserved" do
      assert HidParser.parse_report_descriptor(<<0xC5, 0x01>>) == [
               %HidParser.ReportDescriptor.Reserved{raw: <<0xC5, 0x01>>}
             ]
    end
  end

  describe "Report signed global items" do
    test "negative logical minimum" do
      assert HidParser.parse_report_descriptor(<<0x15, 0xFB>>) == [%LogicalMinimum{value: -5}]
    end

    test "multi-byte negative logical minimum" do
      assert HidParser.parse_report_descriptor(<<0x16, 0x00, 0x80>>) == [
               %LogicalMinimum{value: -32768}
             ]
    end

    test "negative logical maximum" do
      assert HidParser.parse_report_descriptor(<<0x25, 0xFF>>) == [%LogicalMaximum{value: -1}]
    end

    test "negative physical minimum" do
      assert HidParser.parse_report_descriptor(<<0x35, 0x80>>) == [%PhysicalMinimum{value: -128}]
    end

    test "negative physical maximum" do
      assert HidParser.parse_report_descriptor(<<0x45, 0x80>>) == [%PhysicalMaximum{value: -128}]
    end

    test "negative unit exponent" do
      assert HidParser.parse_report_descriptor(<<0x55, 0x0B>>) == [%UnitExponent{value: -5}]
    end
  end

  describe "Report local items" do
    test "usage" do
      assert HidParser.parse_report_descriptor(<<0x09, 0x01>>) == [%Usage{value: 1}]
    end

    test "usage minimum" do
      assert HidParser.parse_report_descriptor(<<0x19, 0x00>>) == [%UsageMinimum{value: 0}]
    end

    test "usage maximum" do
      assert HidParser.parse_report_descriptor(<<0x29, 0x01>>) == [%UsageMaximum{value: 1}]
    end

    test "designator index" do
      assert HidParser.parse_report_descriptor(<<0x39, 0x01>>) == [%DesignatorIndex{value: 1}]
    end

    test "designator minimum" do
      assert HidParser.parse_report_descriptor(<<0x49, 0x00>>) == [%DesignatorMinimum{value: 0}]
    end

    test "designator maximum" do
      assert HidParser.parse_report_descriptor(<<0x59, 0x01>>) == [%DesignatorMaximum{value: 1}]
    end

    test "string index" do
      assert HidParser.parse_report_descriptor(<<0x79, 0x01>>) == [%StringIndex{value: 1}]
    end

    test "string minimum" do
      assert HidParser.parse_report_descriptor(<<0x89, 0x00>>) == [%StringMinimum{value: 0}]
    end

    test "string maximum" do
      assert HidParser.parse_report_descriptor(<<0x99, 0x01>>) == [%StringMaximum{value: 1}]
    end

    test "delimiter" do
      assert HidParser.parse_report_descriptor(<<0xA9, 0x01>>) == [%Delimiter{value: 1}]
    end

    test "reserved" do
      assert HidParser.parse_report_descriptor(<<0xB9, 0x01>>) == [
               %HidParser.ReportDescriptor.Reserved{raw: <<0xB9, 0x01>>}
             ]
    end
  end

  describe "collection tree" do
    test "single collection" do
      tree =
        HidParser.parse_report_descriptor_tree(<<
          0xA1,
          0x01,
          0x05,
          0x01,
          0xC0
        >>)

      assert tree == [
               %Collection{
                 flags: 1,
                 items: [%UsagePage{value: 1}],
                 end_flags: 0
               }
             ]
    end

    test "nested collections" do
      tree =
        HidParser.parse_report_descriptor_tree(<<
          0xA1,
          0x01,
          0xA1,
          0x02,
          0x05,
          0x01,
          0xC0,
          0xC0
        >>)

      assert tree == [
               %Collection{
                 flags: 1,
                 items: [
                   %Collection{
                     flags: 2,
                     items: [%UsagePage{value: 1}],
                     end_flags: 0
                   }
                 ],
                 end_flags: 0
               }
             ]
    end

    test "sibling collections" do
      tree =
        HidParser.parse_report_descriptor_tree(<<
          0xA1,
          0x01,
          0xC0,
          0xA1,
          0x02,
          0xC0
        >>)

      assert tree == [
               %Collection{flags: 1, items: [], end_flags: 0},
               %Collection{flags: 2, items: [], end_flags: 0}
             ]
    end

    test "collection end flags are recorded" do
      tree = HidParser.parse_report_descriptor_tree(<<0xA1, 0x01, 0xC0>>)

      assert tree == [%Collection{flags: 1, items: [], end_flags: 0}]
    end
  end
end
