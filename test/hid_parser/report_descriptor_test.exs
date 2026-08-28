defmodule HidParser.ReportDescriptorTest do
  use ExUnit.Case

  alias HidParser.ReportDescriptor
  alias HidParser.ReportDescriptor.{Output, Feature, Collection, LongItem}

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

  doctest HidParser.ReportDescriptor

  defp items(binary) do
    {:ok, %ReportDescriptor{items: items}} = ReportDescriptor.parse(binary)
    items
  end

  test "usage pages" do
    assert %{1 => %{name: "Generic Desktop"}} = ReportDescriptor.usage_pages()
  end

  test "usage pages degrade to an empty table when the JSON is missing" do
    path = "priv/static/HidUsageTables.json"
    backup = path <> ".bak"

    on_exit(fn ->
      if File.exists?(backup), do: File.rename!(backup, path)
      :persistent_term.erase({ReportDescriptor, :usage_pages})
    end)

    File.rename!(path, backup)
    :persistent_term.erase({ReportDescriptor, :usage_pages})

    assert ReportDescriptor.usage_pages() == %{}
    assert ReportDescriptor.usage_name(1, 6) == nil
  end

  describe "usage lookup" do
    test "usage page name" do
      assert ReportDescriptor.usage_page_name(1) == "Generic Desktop"
    end

    test "usage name" do
      assert ReportDescriptor.usage_name(1, 6) == "Keyboard"
    end

    test "missing usage page" do
      assert ReportDescriptor.usage_page_name(0xFFFF) == nil
    end

    test "missing usage" do
      assert ReportDescriptor.usage_name(1, 0xFFFF) == nil
    end
  end

  test "parse non-binary" do
    assert apply(ReportDescriptor, :parse, [:foo]) ==
             {:error, %HidParser.Error{reason: :invalid_descriptor}}
  end

  test "parse malformed descriptor" do
    assert ReportDescriptor.parse(<<0x05>>) ==
             {:error, %HidParser.Error{reason: :invalid_descriptor}}
  end

  test "parse rejects unclosed collections" do
    assert ReportDescriptor.parse(<<0xA1, 0x01>>) ==
             {:error, %HidParser.Error{reason: :invalid_descriptor}}
  end

  test "parse rejects a stray EndCollection" do
    assert ReportDescriptor.parse(<<0xC0>>) ==
             {:error, %HidParser.Error{reason: :invalid_descriptor}}
  end

  test "parse rejects a stray EndCollection followed by more items" do
    assert ReportDescriptor.parse(<<0xC0, 0x05, 0x01>>) ==
             {:error, %HidParser.Error{reason: :invalid_descriptor}}
  end

  describe "Report main items" do
    test "output" do
      assert items(<<0b1001_00_01, 0x01>>) == [%Output{flags: 1}]
    end

    test "feature" do
      assert items(<<0b1011_00_01, 0x02>>) == [%Feature{flags: 2}]
    end

    test "collection" do
      assert items(<<0b1010_00_01, 0x03, 0xC0>>) ==
               [%Collection{flags: 3, items: [], end_flags: 0}]
    end
  end

  describe "Report global items" do
    test "usage page" do
      assert items(<<0x05, 0x01>>) == [%UsagePage{value: 1}]
    end

    test "logical minimum" do
      assert items(<<0x15, 0x00>>) == [%LogicalMinimum{value: 0}]
    end

    test "logical maximum" do
      assert items(<<0x25, 0x01>>) == [%LogicalMaximum{value: 1}]
    end

    test "physical minimum" do
      assert items(<<0x35, 0x00>>) == [%PhysicalMinimum{value: 0}]
    end

    test "physical maximum" do
      assert items(<<0x45, 0x01>>) == [%PhysicalMaximum{value: 1}]
    end

    test "unit exponent" do
      assert items(<<0x55, 0x01>>) == [%UnitExponent{value: 1}]
    end

    test "unit" do
      assert items(<<0x65, 0x01>>) == [%Unit{value: 1}]
    end

    test "report size" do
      assert items(<<0x75, 0x01>>) == [%ReportSize{value: 1}]
    end

    test "report ID" do
      assert items(<<0x85, 0x01>>) == [%ReportId{value: 1}]
    end

    test "report count" do
      assert items(<<0x95, 0x01>>) == [%ReportCount{value: 1}]
    end

    test "push" do
      assert items(<<0xA4>>) == [%Push{}]
    end

    test "pop" do
      assert items(<<0xB4>>) == [%Pop{}]
    end

    test "push with a body is rejected" do
      assert ReportDescriptor.parse(<<0xA5, 0x01>>) ==
               {:error, %HidParser.Error{reason: :invalid_descriptor}}
    end

    test "pop with a body is rejected" do
      assert ReportDescriptor.parse(<<0xB5, 0x01>>) ==
               {:error, %HidParser.Error{reason: :invalid_descriptor}}
    end

    test "reserved" do
      assert items(<<0xC5, 0x01>>) == [%HidParser.ReportDescriptor.Reserved{raw: <<0xC5, 0x01>>}]
    end
  end

  describe "Report signed global items" do
    test "negative logical minimum" do
      assert items(<<0x15, 0xFB>>) == [%LogicalMinimum{value: -5}]
    end

    test "multi-byte negative logical minimum" do
      assert items(<<0x16, 0x00, 0x80>>) == [%LogicalMinimum{value: -32_768}]
    end

    test "negative logical maximum" do
      assert items(<<0x25, 0xFF>>) == [%LogicalMaximum{value: -1}]
    end

    test "negative physical minimum" do
      assert items(<<0x35, 0x80>>) == [%PhysicalMinimum{value: -128}]
    end

    test "negative physical maximum" do
      assert items(<<0x45, 0x80>>) == [%PhysicalMaximum{value: -128}]
    end

    test "negative unit exponent" do
      assert items(<<0x55, 0x0B>>) == [%UnitExponent{value: -5}]
    end
  end

  describe "Report local items" do
    test "usage" do
      assert items(<<0x09, 0x01>>) == [%Usage{value: 1}]
    end

    test "usage minimum" do
      assert items(<<0x19, 0x00>>) == [%UsageMinimum{value: 0}]
    end

    test "usage maximum" do
      assert items(<<0x29, 0x01>>) == [%UsageMaximum{value: 1}]
    end

    test "designator index" do
      assert items(<<0x39, 0x01>>) == [%DesignatorIndex{value: 1}]
    end

    test "designator minimum" do
      assert items(<<0x49, 0x00>>) == [%DesignatorMinimum{value: 0}]
    end

    test "designator maximum" do
      assert items(<<0x59, 0x01>>) == [%DesignatorMaximum{value: 1}]
    end

    test "string index" do
      assert items(<<0x79, 0x01>>) == [%StringIndex{value: 1}]
    end

    test "string minimum" do
      assert items(<<0x89, 0x00>>) == [%StringMinimum{value: 0}]
    end

    test "string maximum" do
      assert items(<<0x99, 0x01>>) == [%StringMaximum{value: 1}]
    end

    test "delimiter" do
      assert items(<<0xA9, 0x01>>) == [%Delimiter{value: 1}]
    end

    test "reserved" do
      assert items(<<0xB9, 0x01>>) == [%HidParser.ReportDescriptor.Reserved{raw: <<0xB9, 0x01>>}]
    end
  end

  describe "long items" do
    test "long item" do
      assert items(<<0xFF, 0x01, 0x01, 0xAA>>) == [%LongItem{tag: 1, data: <<0xAA>>}]
    end

    test "long item with no data" do
      assert items(<<0xFF, 0x00, 0x01>>) == [%LongItem{tag: 1, data: <<>>}]
    end

    test "long item data size precedes the tag" do
      assert items(<<0xFF, 0x02, 0x05, 0xAA, 0xBB>>) == [%LongItem{tag: 5, data: <<0xAA, 0xBB>>}]
    end

    test "long item followed by a short item" do
      assert items(<<0xFF, 0x01, 0x01, 0xAA, 0x05, 0x01>>) == [
               %LongItem{tag: 1, data: <<0xAA>>},
               %UsagePage{value: 1}
             ]
    end
  end

  describe "collection tree" do
    test "single collection" do
      assert items(<<0xA1, 0x01, 0x05, 0x01, 0xC0>>) == [
               %Collection{
                 flags: 1,
                 items: [%UsagePage{value: 1}],
                 end_flags: 0
               }
             ]
    end

    test "nested collections" do
      assert items(<<
               0xA1,
               0x01,
               0xA1,
               0x02,
               0x05,
               0x01,
               0xC0,
               0xC0
             >>) == [
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
      assert items(<<0xA1, 0x01, 0xC0, 0xA1, 0x02, 0xC0>>) == [
               %Collection{flags: 1, items: [], end_flags: 0},
               %Collection{flags: 2, items: [], end_flags: 0}
             ]
    end

    test "collection end flags are recorded" do
      assert items(<<0xA1, 0x01, 0xC0>>) == [%Collection{flags: 1, items: [], end_flags: 0}]
    end
  end
end
