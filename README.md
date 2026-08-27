# HidParser

An Elixir library for parsing USB HID report descriptors (HID 1.11) and the
reports they describe.

The API is a three-stage pipeline:

```elixir
{:ok, descriptor} = HidParser.ReportDescriptor.parse(descriptor_bytes)   # syntax
{:ok, codec}      = HidParser.ReportCodec.compile(descriptor, vid: vid, pid: pid) # semantics
{:ok, report}     = HidParser.ReportCodec.decode(codec, report_bytes)    # runtime
{:ok, binary}     = HidParser.ReportCodec.encode(codec, report)          # runtime
```

Every stage returns `{:ok, _}` or `{:error, %HidParser.Error{}}`.

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

## Requirements

- Elixir `~> 1.20` (uses the native `JSON` module, Elixir 1.18+)
- Erlang/OTP 29

Versions are pinned via [mise](https://mise.jdx.dev) in `mise.toml`.

---

# Stage 1 — Parsing the descriptor

`HidParser.ReportDescriptor.parse/1` decodes a descriptor binary into a
`%HidParser.ReportDescriptor{}` — the collection tree of items (the *syntax*):

```elixir
{:ok, descriptor} = HidParser.ReportDescriptor.parse(binary)
%HidParser.ReportDescriptor{
  items: [
    %HidParser.ReportDescriptor.Collection{flags: 1, items: [...], end_flags: 0},
    ...
  ]
}
```

The flat item list is an internal detail; the tree preserves the nesting declared
by `Collection` items. Each item is a struct under `HidParser.ReportDescriptor`,
named after the HID 1.11 item it represents (`UsagePage`, `Usage`, `Input`,
`LogicalMaximum`, ...). Signed global items (`LogicalMinimum`, `PhysicalMaximum`,
`UnitExponent`) decode their value as two's complement:

```elixir
iex> HidParser.ReportDescriptor.parse(<<0x15, 0xFB>>)
{:ok, %HidParser.ReportDescriptor{items: [%HidParser.ReportDescriptor.LogicalMinimum{value: -5}]}}
```

Malformed or truncated descriptors return
`{:error, %HidParser.Error{reason: :invalid_descriptor}}`.

## Usage tables

The HID usage tables (`priv/static/HidUsageTables.json`) are fetched at build
time and parsed lazily on first access. They map a `{usage_page, usage_id}` pair
to a name:

```elixir
iex> HidParser.ReportDescriptor.usage_page_name(1)
"Generic Desktop"

iex> HidParser.ReportDescriptor.usage_name(7, 0x04)
"Keyboard A"
```

---

# Stage 2 — Compiling the codec

`HidParser.ReportCodec.compile/2` resolves global/local item state, `Push`/`Pop`,
collection nesting, report IDs and usage inheritance into a
`%HidParser.ReportCodec{}` — flat field lists, one per report id:

```elixir
{:ok, codec} = HidParser.ReportCodec.compile(descriptor, vid: 0x046A, pid: 0x00B0)

%HidParser.ReportCodec{
  vid: 0x046A, pid: 0x00B0,
  reports: %{1 => [%HidParser.ReportCodec.Field{}, ...]},
  uses_report_id?: true
}
```

Each `HidParser.ReportCodec.Field` carries its type, bit offset/size/count,
signedness, decoded flags, logical/physical range, unit, and usages. A descriptor
without report IDs has a single report keyed `0` and `uses_report_id?: false`.
An unbalanced `Push`/`Pop` returns
`{:error, %HidParser.Error{reason: :pop_without_push | :push_without_pop}}`.

---

# Stage 3 — Decoding and encoding reports

## Decode

`HidParser.ReportCodec.decode/2` turns report bytes into a `%HidParser.Report{}`:

```elixir
{:ok, report} = HidParser.ReportCodec.decode(codec, report_bytes)

%HidParser.Report{
  report_id: 1,
  values: [
    %HidParser.Report.Value{field: modifiers, index: 0, logical: 1},
    %HidParser.Report.Value{field: modifiers, index: 1, logical: 0},
    %HidParser.Report.Value{field: keys, index: 0, logical: 0x04}
  ]
}
```

There is one `HidParser.Report.Value` per *element*. Only the logical integer is
stored — lossless and roundtrippable; constant/padding fields are skipped.

## Encode

`HidParser.ReportCodec.encode/2` turns the report back into bytes:

```elixir
{:ok, binary} = HidParser.ReportCodec.encode(codec, report)
```

`encode(decode(binary)) == binary` holds (for reports whose constant bits are
zero). `encode` validates the values against the codec and returns
`{:error, %HidParser.Error{}}` for an unknown report id, missing/extra fields,
wrong element counts, or out-of-range logical values.

## Value accessors

Scaling is exposed through accessors on `HidParser.Report.Value`, never stored:

```elixir
HidParser.Report.Value.logical(value)   # the canonical integer
HidParser.Report.Value.physical(value)  # linear logical -> physical (or nil)
HidParser.Report.Value.scaled(value)    # physical * 10^unit_exponent (or nil)
HidParser.Report.Value.usage(value)     # {usage_page, usage_id}
HidParser.Report.Value.name(value)      # usage name (or "0xpage:0xusage")
```

```elixir
iex> field = %HidParser.ReportCodec.Field{logical_min: 0, logical_max: 100, physical_min: 0, physical_max: 1000}
iex> value = %HidParser.Report.Value{field: field, index: 0, logical: 50}
iex> HidParser.Report.Value.physical(value)
500.0
```

## A complete example

```elixir
descriptor = <<
  0x05, 0x01, 0x09, 0x06, 0xA1, 0x01,        # Usage Page (Desktop), Usage (Keyboard), Collection
  0x85, 0x01,                                  # Report ID (1)
  0x05, 0x07, 0x19, 0xE0, 0x29, 0xE7,         # Usage Page (Keyboard), Usage Min/Max (modifiers)
  0x15, 0x00, 0x25, 0x01, 0x75, 0x01, 0x95, 0x08, 0x81, 0x02,  # 8 x 1-bit modifiers
  0x95, 0x01, 0x75, 0x08, 0x81, 0x01,         # 1 x 8-bit constant padding
  0x95, 0x06, 0x75, 0x08, 0x15, 0x00, 0x25, 0x65, 0x05, 0x07, 0x19, 0x00, 0x29, 0x65, 0x81, 0x00,  # 6 x 8-bit keys (array)
  0xC0                                         # End Collection
>>

{:ok, descriptor} = HidParser.ReportDescriptor.parse(descriptor)
{:ok, codec}      = HidParser.ReportCodec.compile(descriptor)

[modifiers, _padding, keys] = codec.reports[1]

report = %HidParser.Report{
  report_id: 1,
  values: [
    %HidParser.Report.Value{field: modifiers, index: 0, logical: 1},
    %HidParser.Report.Value{field: keys, index: 0, logical: 0x04},
    %HidParser.Report.Value{field: keys, index: 1, logical: 0x1E}
  ]
}

{:ok, <<1, 0x01, 0x00, 0x04, 0x1E, 0, 0, 0, 0>>} = HidParser.ReportCodec.encode(codec, report)
```

---

# Errors

All failures are `{:error, %HidParser.Error{reason: ..., detail: ...}}`. `reason`
is one of `:invalid_descriptor`, `:pop_without_push`, `:push_without_pop`,
`:empty_report`, `:no_reports`, `:unknown_report_id`, `:field_mismatch`,
`:missing_values`, `:value_count_mismatch`, or `:out_of_range`; `detail` carries
the context (the offending id, field, or value). `HidParser.Error` implements
`Exception`, so it can also be `raise`d.

# Inspecting

All four structs implement `Inspect` with a concise `#Struct<...>` form; pass
`custom_options: [verbose: true]` to dump the full struct:

```elixir
iex> inspect(report)
"#Report<1, [#Report.Value<Keyboard LeftControl = 1>, ...]>"

iex> inspect(report, custom_options: [verbose: true])
"%HidParser.Report{report_id: 1, values: [%HidParser.Report.Value{...}]}"
```

# Roundtrip guarantees and edge cases

- **Bit packing** — fields are packed LSB-first in field order; a count-N field
  contributes N consecutive values of `size` bits each.
- **Signedness** — a field is signed iff `logical_min < 0`.
- **Report ID** — when the descriptor uses `ReportId`, the first byte of every
  report is the id.
- **Constant/padding fields** roundtrip as *zero* bits; a device padding with
  non-zero constant bits will not roundtrip bit-exactly.
- **Collections** — offsets are computed across collection boundaries; collection
  usages apply to contained fields that declare none.

---

# Tests & fixtures

The test suite builds raw descriptors inline — no fixture files are committed.

Real-world descriptors are fetched at test time from
[`hid-tools`](https://gitlab.freedesktop.org/libevdev/hid-tools) (GPL-2.0):

```sh
mix hid_parser.fetch_fixtures
```

This downloads a few pinned cases into `test/fixtures/` (gitignored). The
fixture-backed tests roundtrip every descriptor and **skip** when the fixtures
are absent, so `mix test` stays green offline.

---

# Development

```sh
mix test    # run the test suite
mix format  # format the code
mix check   # curated checks (ex_check)
mix credo   # static analysis
mix doctor  # documentation coverage
mix docs    # generate HTML docs
```

## References

- [Device Class Definition for HID 1.11](https://www.usb.org/sites/default/files/hid1_11.pdf)
- [HID Usage Tables](https://www.usb.org/sites/default/files/hut1_22.pdf)
