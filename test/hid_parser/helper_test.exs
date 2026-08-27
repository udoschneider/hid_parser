defmodule HidParser.HelperTest do
  use ExUnit.Case
  alias HidParser.Helper
  doctest HidParser.Helper

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
end
