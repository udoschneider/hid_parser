# HidParser

An Elixir library for parsing USB HID report descriptors (HID 1.11) into
structured items.

## Installation

The package is not yet published to [Hex](https://hex.pm). To use it from a Git
dependency, add it to `mix.exs`:

```elixir
def deps do
  [
    {:hid_parser, git: "https://github.com/udoschneider/hid_parser.git", tag: "0.1.0"}
  ]
end
```

## Usage

```elixir
iex> HidParser.parse_report_descriptor(<<0x05, 0x01, 0x09, 0x06, 0xA1, 0x01, 0x85, 0x01, 0xC0>>)
[
  %HidParser.ReportDescriptor.UsagePage{value: 1},
  %HidParser.ReportDescriptor.Usage{value: 6},
  %HidParser.ReportDescriptor.Collection{flags: 1},
  %HidParser.ReportDescriptor.ReportId{value: 1},
  %HidParser.ReportDescriptor.EndCollection{flags: 0}
]
```

`parse_report_descriptor/1` returns a flat list of report descriptor items.
Each item is a struct named after the HID 1.11 item it represents (see
`HidParser.ReportDescriptor` for the full list). Main items (`Input`, `Output`,
`Feature`) carry their bit flags in a `flags` field; global and local items carry
a signed `value`; `Collection` records its child `items` and `end_flags`.

The HID usage tables are fetched at build time (into `priv/static/HidUsageTables.json`)
and parsed lazily on first call, then exposed via:

```elixir
iex> HidParser.ReportDescriptor.usage_pages()
%{1 => %{kind: ..., name: "Generic Desktop", usage_ids: %{...}}}
```

## Requirements

- Elixir `~> 1.20` (requires the native `JSON` module, Elixir 1.18+)
- Erlang/OTP 29

Versions are pinned via [mise](https://mise.jdx.dev) in `mise.toml`.

## Development

```sh
mix test    # run the test suite
mix format  # format the code
mix check   # curated checks (ex_check)
mix credo   # static analysis
mix doctor  # documentation coverage
```

## References

- [Device Class Definition for HID 1.11](https://www.usb.org/sites/default/files/hid1_11.pdf)
- [HID Usage Tables](https://www.usb.org/sites/default/files/hut1_22.pdf)
