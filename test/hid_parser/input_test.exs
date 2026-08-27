defmodule HidParser.InputTest do
  use ExUnit.Case
  alias HidParser.ReportDescriptor.Input

  test "1 byte" do
    assert HidParser.parse_report_descriptor(<<0b1000_00_01, 0x01>>) == [%Input{flags: 0x01}]
  end

  test "2 bytes" do
    assert HidParser.parse_report_descriptor(<<0b1000_00_10, 0x10, 0x02>>) == [
             %Input{flags: 0x0210}
           ]
  end

  test "4 bytes" do
    assert HidParser.parse_report_descriptor(<<0b1000_00_11, 0x10, 0x00, 0x00, 0x04>>) == [
             %Input{flags: 0x04000010}
           ]
  end
end
