defmodule HidParser.Helper do
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

      iex> HidParser.Helper.shortsize_expand(0)
      0
      iex> HidParser.Helper.shortsize_expand(1)
      1
      iex> HidParser.Helper.shortsize_expand(2)
      2
      iex> HidParser.Helper.shortsize_expand(3)
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

      iex> HidParser.Helper.shortsize_compress(0)
      0
      iex> HidParser.Helper.shortsize_compress(1)
      1
      iex> HidParser.Helper.shortsize_compress(2)
      2
      iex> HidParser.Helper.shortsize_compress(4)
      3

  """
  @spec shortsize_compress(size :: integer()) :: integer()
  def shortsize_compress(size)
  def shortsize_compress(0), do: 0
  def shortsize_compress(1), do: 1
  def shortsize_compress(2), do: 2
  def shortsize_compress(4), do: 3
  def shortsize_compress(_), do: raise(ArgumentError, message: "invalid size")

  def parse_main_flags(<<>>), do: 0
  def parse_main_flags(<<flags::integer-size(8)>>), do: flags
  def parse_main_flags(<<flags::integer-size(16)>>), do: flags
  def parse_main_flags(<<flags::integer-size(32)>>), do: flags
end
