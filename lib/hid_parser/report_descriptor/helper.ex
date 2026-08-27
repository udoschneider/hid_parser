defmodule HidParser.ReportDescriptor.Helper do
  @moduledoc """
  This module contains several helper function for HID Descriptor parsing.
  """

  @doc """
  Expands a `bSize` into a size. Inverse function to `shortsize_compress/1`.

  See HID/6.2.2.2 for more details.

  | Raw | Expanded |
  |-----|----------|
  | `0` | `0`      |
  | `1` | `1`      |
  | `2` | `2`      |
  | `3` | `4`      |

  ## Examples

      iex> HidParser.ReportDescriptor.Helper.shortsize_expand(0)
      0
      iex> HidParser.ReportDescriptor.Helper.shortsize_expand(1)
      1
      iex> HidParser.ReportDescriptor.Helper.shortsize_expand(2)
      2
      iex> HidParser.ReportDescriptor.Helper.shortsize_expand(3)
      4
  """
  @spec shortsize_expand(bSize :: integer()) :: integer()
  def shortsize_expand(bSize)
  def shortsize_expand(0), do: 0
  def shortsize_expand(1), do: 1
  def shortsize_expand(2), do: 2
  def shortsize_expand(3), do: 4
  def shortsize_expand(_), do: raise(ArgumentError, message: "invalid bSize")

  @doc """
  Compresses a size into a `bSize`. Inverse function to `shortsize_expand/1`.

  See HID/6.2.2.2 for more details.

      iex> HidParser.ReportDescriptor.Helper.shortsize_compress(0)
      0
      iex> HidParser.ReportDescriptor.Helper.shortsize_compress(1)
      1
      iex> HidParser.ReportDescriptor.Helper.shortsize_compress(2)
      2
      iex> HidParser.ReportDescriptor.Helper.shortsize_compress(4)
      3

  """
  @spec shortsize_compress(size :: integer()) :: integer()
  def shortsize_compress(size)
  def shortsize_compress(0), do: 0
  def shortsize_compress(1), do: 1
  def shortsize_compress(2), do: 2
  def shortsize_compress(4), do: 3
  def shortsize_compress(_), do: raise(ArgumentError, message: "invalid size")

  @doc """
  Decodes an item's raw data field as an unsigned little-endian integer.

  Used both for main-item flags (`Input`/`Output`/`Feature`/`Collection`) and
  for unsigned global/local values such as `UsagePage`, `ReportId` or `Usage`.
  Multi-byte values are little-endian per the HID spec (HID/6.2.2).

  ## Examples

      iex> HidParser.ReportDescriptor.Helper.parse_unsigned(<<>>)
      0
      iex> HidParser.ReportDescriptor.Helper.parse_unsigned(<<0x01>>)
      1
      iex> HidParser.ReportDescriptor.Helper.parse_unsigned(<<0x10, 0x02>>)
      0x0210
  """
  @spec parse_unsigned(binary()) :: non_neg_integer()
  def parse_unsigned(<<>>), do: 0
  def parse_unsigned(<<flags::little-integer-size(8)>>), do: flags
  def parse_unsigned(<<flags::little-integer-size(16)>>), do: flags
  def parse_unsigned(<<flags::little-integer-size(32)>>), do: flags

  @doc """
  Decodes a data field as a two's complement signed integer.

  Used for signed global items such as Logical Minimum/Maximum
  (HID/6.2.2.4).

  ## Examples

      iex> HidParser.ReportDescriptor.Helper.parse_signed(<<>>)
      0
      iex> HidParser.ReportDescriptor.Helper.parse_signed(<<0x7F>>)
      127
      iex> HidParser.ReportDescriptor.Helper.parse_signed(<<0x80>>)
      -128
      iex> HidParser.ReportDescriptor.Helper.parse_signed(<<0xFB>>)
      -5
      iex> HidParser.ReportDescriptor.Helper.parse_signed(<<0x00, 0x80>>)
      -32768
  """
  @spec parse_signed(binary()) :: integer()
  def parse_signed(<<>>), do: 0
  def parse_signed(<<value::little-signed-integer-size(8)>>), do: value
  def parse_signed(<<value::little-signed-integer-size(16)>>), do: value
  def parse_signed(<<value::little-signed-integer-size(32)>>), do: value

  @doc """
  Decodes a Unit Exponent data field (HID/6.2.2.7): a signed 4-bit value in
  the low nibble of the byte.

  ## Examples

      iex> HidParser.ReportDescriptor.Helper.parse_unit_exponent(<<0x01>>)
      1
      iex> HidParser.ReportDescriptor.Helper.parse_unit_exponent(<<0x0B>>)
      -5
  """
  @spec parse_unit_exponent(binary()) :: integer()
  def parse_unit_exponent(<<_reserved::4, value::signed-integer-size(4)>>), do: value
end
