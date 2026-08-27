defmodule HidParser.ReportDescriptor.Helper do
  @moduledoc """
  This module contains several helper function for HID Descriptor parsing.
  """

  import Bitwise

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
  (HID/6.2.2.7).

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

  @doc """
  Decodes a main item `flags` value into a map of the HID 1.11 flag bits.

  See HID 1.11 §6.2.2.5. Each key is named after the bit's set (`1`) meaning:

    * `:constant` — bit 0 (vs Data)
    * `:variable` — bit 1 (vs Array)
    * `:relative` — bit 2 (vs Absolute)
    * `:wrap` — bit 3 (vs No Wrap)
    * `:non_linear` — bit 4 (vs Linear)
    * `:no_preferred` — bit 5 (vs Preferred State)
    * `:null_state` — bit 6 (vs No Null Position)
    * `:buffered_bytes` — bit 8 (vs Bit Field)

  ## Examples

      iex> HidParser.ReportDescriptor.Helper.decode_flags(0x02).variable
      true

  """
  @spec decode_flags(non_neg_integer()) :: map()
  def decode_flags(flags) when is_integer(flags) do
    %{
      constant: (flags &&& 0x001) != 0,
      variable: (flags &&& 0x002) != 0,
      relative: (flags &&& 0x004) != 0,
      wrap: (flags &&& 0x008) != 0,
      non_linear: (flags &&& 0x010) != 0,
      no_preferred: (flags &&& 0x020) != 0,
      null_state: (flags &&& 0x040) != 0,
      buffered_bytes: (flags &&& 0x100) != 0
    }
  end

  @doc """
  Decodes a Unit value into its component parts.

  The Unit item packs the measurement system and the exponents for the seven
  SI base units into nibbles (HID 1.11 §6.2.2.13). Returns a map with:

    * `:system` — `:none`, `:si_linear`, `:si_rotation`, `:english_linear`,
      `:english_rotation`, or `{:reserved, n}`
    * `:length`, `:mass`, `:time`, `:temperature`, `:current`,
      `:luminous_intensity` — signed 4-bit exponents in the range `-8..7`

  ## Examples

      iex> HidParser.ReportDescriptor.Helper.decode_unit(0xF1).length
      -1

  """
  @spec decode_unit(non_neg_integer()) :: map()
  def decode_unit(unit) when is_integer(unit) do
    %{
      system: unit_system(unit &&& 0xF),
      length: signed_nibble(unit, 4),
      mass: signed_nibble(unit, 8),
      time: signed_nibble(unit, 12),
      temperature: signed_nibble(unit, 16),
      current: signed_nibble(unit, 20),
      luminous_intensity: signed_nibble(unit, 24)
    }
  end

  defp signed_nibble(value, shift) do
    nibble = value >>> shift &&& 0xF
    if nibble < 8, do: nibble, else: nibble - 16
  end

  defp unit_system(0), do: :none
  defp unit_system(1), do: :si_linear
  defp unit_system(2), do: :si_rotation
  defp unit_system(3), do: :english_linear
  defp unit_system(4), do: :english_rotation
  defp unit_system(n), do: {:reserved, n}
end
