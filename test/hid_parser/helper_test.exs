defmodule HidParser.ReportDescriptor.HelperTest do
  use ExUnit.Case
  alias HidParser.ReportDescriptor.Helper
  doctest HidParser.ReportDescriptor.Helper

  describe "shortsize_expand" do
    test "raises on invalid size" do
      assert_raise ArgumentError, fn -> Helper.shortsize_expand(-1) end
      assert_raise ArgumentError, fn -> Helper.shortsize_expand(4) end
    end
  end

  describe "shortsize_compress" do
    test "raises on invalid size" do
      assert_raise ArgumentError, fn -> Helper.shortsize_compress(-1) end
      assert_raise ArgumentError, fn -> Helper.shortsize_compress(3) end
      assert_raise ArgumentError, fn -> Helper.shortsize_compress(8) end
    end
  end

  describe "decode_flags" do
    test "all clear" do
      assert Helper.decode_flags(0) == %{
               constant: false,
               variable: false,
               relative: false,
               wrap: false,
               non_linear: false,
               no_preferred: false,
               null_state: false,
               volatile: false,
               buffered_bytes: false
             }
    end

    test "constant and variable" do
      flags = Helper.decode_flags(0x03)
      assert flags.constant
      assert flags.variable
    end

    test "volatile" do
      assert Helper.decode_flags(0x080).volatile
    end

    test "buffered bytes" do
      assert Helper.decode_flags(0x100).buffered_bytes
    end
  end

  describe "decode_unit" do
    test "none" do
      assert Helper.decode_unit(0) == %{
               system: :none,
               length: 0,
               mass: 0,
               time: 0,
               temperature: 0,
               current: 0,
               luminous_intensity: 0
             }
    end

    test "si linear with negative length exponent" do
      assert Helper.decode_unit(0xF1) == %{
               system: :si_linear,
               length: -1,
               mass: 0,
               time: 0,
               temperature: 0,
               current: 0,
               luminous_intensity: 0
             }
    end

    test "si rotation" do
      assert Helper.decode_unit(0x12) == %{
               system: :si_rotation,
               length: 1,
               mass: 0,
               time: 0,
               temperature: 0,
               current: 0,
               luminous_intensity: 0
             }
    end
  end
end
