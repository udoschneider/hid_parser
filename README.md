# HidParser

An Elixir library for parsing and working with USB HID report descriptors
(HID 1.11) and the reports they describe.

It does two things, in two layers:

1. **Parse** a report descriptor binary into structured items — the *syntax*.
2. **Compile** those items into a *report model* of per-report fields, and use
   that model to **parse** binary reports into typed/scaled values and **build**
   the binary back — the *semantics*.

```elixir
descriptor = File.read!("/sys/bus/hid/devices/.../report_descriptor")

report = HidParser.Report.compile(descriptor, vid: 0x046A, pid: 0x00B0)

{:ok, values} = HidParser.Report.parse(report, report_binary)   # canonical values
{:ok, binary} = HidParser.Report.build(report, values)          # roundtrip back

HidParser.Report.to_keyword(report, values)                     # convenience list
```

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

# Layer 1 — Descriptor items

The first layer turns a raw descriptor binary into a flat list (or nested tree)
of item structs. This is *syntax only*: it decodes the descriptor's byte format
(HID 1.11 §6.2.2) but does not interpret global/local state, report layout, or
usage meaning.

## Parsing a descriptor

```elixir
items = HidParser.parse_report_descriptor(descriptor)
```

`parse_report_descriptor/1` returns a flat list of items, one struct per HID
item:

```elixir
iex> HidParser.parse_report_descriptor(<<0x05, 0x01, 0x09, 0x06, 0xA1, 0x01, 0x85, 0x01, 0xC0>>)
[
  %HidParser.ReportDescriptor.UsagePage{value: 1},
  %HidParser.ReportDescriptor.Usage{value: 6},
  %HidParser.ReportDescriptor.Collection{flags: 1, items: [], end_flags: 0},
  %HidParser.ReportDescriptor.ReportId{value: 1},
  %HidParser.ReportDescriptor.EndCollection{flags: 0}
]
```

## Item structs

Each item type is a struct under `HidParser.ReportDescriptor`, named after the
HID 1.11 item. The struct's field shape depends on the item kind:

| Kind | Example | Field |
|------|---------|-------|
| Global/Local | `UsagePage`, `Usage`, `ReportSize`, `LogicalMaximum` | `value` (integer) |
| Main | `Input`, `Output`, `Feature`, `Collection`, `EndCollection` | `flags` (integer) |
| `Collection` | — | `flags`, `items`, `end_flags` |
| `Reserved` | unknown tag | `raw` (binary) |
| `LongItem` | vendor-defined | `tag`, `data` |

Signed global items (`LogicalMinimum`, `LogicalMaximum`, `PhysicalMinimum`,
`PhysicalMaximum`, `UnitExponent`) decode their value as two's complement, so a
descriptor byte `0xFB` on a `LogicalMinimum` becomes `-5`:

```elixir
iex> HidParser.parse_report_descriptor(<<0x15, 0xFB>>)
[%HidParser.ReportDescriptor.LogicalMinimum{value: -5}]
```

## The collection tree

`parse_report_descriptor_tree/1` nests collections, accumulating each
`Collection`'s child items and recording the matching `EndCollection` flags:

```elixir
tree = HidParser.parse_report_descriptor_tree(<<0xA1, 0x01, 0x05, 0x01, 0xC0>>)
# [
#   %HidParser.ReportDescriptor.Collection{
#     flags: 1, items: [%HidParser.ReportDescriptor.UsagePage{value: 1}], end_flags: 0
#   }
# ]
```

## Usage tables

The HID usage tables (`priv/static/HidUsageTables.json`) are fetched at build
time and parsed lazily on first access. They map a `{usage_page, usage_id}` pair
to a human-readable name:

```elixir
iex> HidParser.ReportDescriptor.usage_page_name(1)
"Generic Desktop"

iex> HidParser.ReportDescriptor.usage_name(1, 6)
"Keyboard"

iex> HidParser.ReportDescriptor.usage_name(7, 0x04)
"Keyboard A"
```

Both return `nil` when the page or usage id is not in the tables.

---

# Layer 2 — The report model

The second layer *compiles* the item stream into a `%HidParser.Report{}` of
per-report field lists. It resolves everything the syntax layer left open:

- global/local item state (`ReportSize`, `ReportCount`, logical/physical ranges,
  `Unit`, …),
- `Push`/`Pop` state stack,
- collection nesting and usage inheritance,
- report IDs,
- usage identity (`{usage_page, usage_id}`).

## Compiling a descriptor

```elixir
report = HidParser.Report.compile(descriptor)
```

Optional metadata on `compile/2`:

| Option | Meaning |
|--------|---------|
| `:vid`, `:pid` | device metadata stored verbatim on the report |
| `:report_id` | the key under which the single report is stored when the descriptor has *no* report IDs (default `0`); ignored when the descriptor uses its own report IDs |

`compile/2` raises `ArgumentError` on a structurally invalid descriptor
(unbalanced `Push`/`Pop` or `Collection`/`EndCollection`).

## The `Report` struct

```elixir
%HidParser.Report{
  vid: 0x046A,            # integer | nil
  pid: 0x00B0,            # integer | nil
  reports: %{             # report_id => ordered list of fields
    1 => [%HidParser.Report.Field{}, ...]
  },
  uses_report_id?: true   # whether reports carry a leading id byte
}
```

A descriptor without report IDs has a single report keyed `0` and
`uses_report_id?: false`.

## The `Field` struct

Each field is the product of one `Input`/`Output`/`Feature` main item:

```elixir
%HidParser.Report.Field{
  type: :input,              # :input | :output | :feature
  report_id: 1,
  offset: 0,                 # bit offset within the report (after the id byte)
  size: 1,                   # bits per element
  count: 8,                  # number of elements
  signed?: false,            # logical_min < 0
  flags: %{                  # HidParser.ReportDescriptor.Helper.decode_flags/1
    constant: false, variable: true, relative: false, wrap: false,
    non_linear: false, no_preferred: false, null_state: false,
    buffered_bytes: false
  },
  logical_min: 0, logical_max: 1,
  physical_min: nil, physical_max: nil,
  unit: nil,                 # decode_unit/1 map | nil
  unit_exponent: 0,
  usage_page: 7,
  usages: [0xE0, 0xE1, ...]  # per-element usage ids (see below)
}
```

### Usages

`usage_page` is shared by every element of a field (it is a global item); the
`usages` list holds the ids and is derived from the local items preceding the
main item:

- a single `Usage` → `[id]` (that id applies to every element),
- `UsageMinimum`/`UsageMaximum` on a **variable** field → expanded to `count`
  per-element ids,
- `UsageMinimum`/`UsageMaximum` on an **array** field → the full `min..max`
  range (the domain of values each element may select),
- no local usage → inherited from the nearest enclosing collection that
  declares one.

---

# Parsing and building reports

## Canonical values

`parse/2` decodes a binary report into *canonical values*: an ordered list of
`{field, values}` tuples where `values` is the list of logical integers (one per
element). Constant fields never appear — they are descriptor-driven and
roundtrip as zero bits.

```elixir
{:ok, values} = HidParser.Report.parse(report, report_binary)
# [
#   {%HidParser.Report.Field{...}, [1, 0, 1, 0, 0, 0, 0, 0]},
#   {%HidParser.Report.Field{...}, [0x04, 0x1E, 0, 0, 0, 0]}
# ]
```

## Building

`build/2` takes canonical values and produces the binary back:

```elixir
{:ok, binary} = HidParser.Report.build(report, values)
```

`values` must list the non-constant fields in report order. Constant fields are
packed as zero bits automatically.

### A complete example

```elixir
descriptor = <<
  0x05, 0x01, 0x09, 0x06, 0xA1, 0x01,          # Usage Page (Desktop), Usage (Keyboard), Collection
  0x85, 0x01,                                    # Report ID (1)
  0x05, 0x07, 0x19, 0xE0, 0x29, 0xE7,           # Usage Page (Keyboard), Usage Min/Max (modifiers)
  0x15, 0x00, 0x25, 0x01, 0x75, 0x01, 0x95, 0x08, 0x81, 0x02,  # 8 x 1-bit modifiers
  0x95, 0x01, 0x75, 0x08, 0x81, 0x01,           # 1 x 8-bit constant padding
  0x95, 0x06, 0x75, 0x08, 0x15, 0x00, 0x25, 0x65, 0x05, 0x07, 0x19, 0x00, 0x29, 0x65, 0x81, 0x00,  # 6 x 8-bit keys (array)
  0xC0                                           # End Collection
>>

report = HidParser.Report.compile(descriptor)
[modifiers, _padding, keys] = report.reports[1]

values = [{modifiers, [1, 0, 1, 0, 0, 0, 0, 0]}, {keys, [0x04, 0x1E, 0, 0, 0, 0]}]

{:ok, binary} = HidParser.Report.build(report, values)
# <<1, 0x05, 0x00, 0x04, 0x1E, 0, 0, 0, 0>>

{:ok, ^values} = HidParser.Report.parse(report, binary)
```

## Error handling

`parse/2` and `build/2` return `{:ok, _}` / `{:error, reason}`. The error
reasons are:

| Call | Reason |
|------|--------|
| `parse/2` with an unknown report id | `{:unknown_report_id, id}` |
| `parse/2` on an empty report with report ids | `:empty_report` |
| `build/2` missing a field's values | `{:missing_values, field}` |
| `build/2` wrong number of values | `{:value_count_mismatch, field, n}` |
| `build/2` value outside `logical_min..logical_max` | `{:out_of_range, field, value}` |
| `build/2` more values than fields | `{:extra_values, leftover}` |

---

# Value accessors

Canonical storage is the logical integer — lossless and roundtrippable.
Physical/SI floats are *never* stored; they are derived on demand:

```elixir
HidParser.Report.value(field, v)     # logical value (identity)
HidParser.Report.physical(field, v)  # linear logical -> physical mapping
HidParser.Report.scaled(field, v)    # SI value = physical * 10^unit_exponent
```

`physical/2` applies the linear mapping

```
physical = logical * (physical_max - physical_min) / (logical_max - logical_min) + physical_min
```

and returns `nil` when the field declares no physical range or the logical range
is degenerate. `scaled/2` multiplies by `10^unit_exponent`.

```elixir
field = %HidParser.Report.Field{
  logical_min: 0, logical_max: 100,
  physical_min: 0, physical_max: 1000,
  unit_exponent: -1
}

HidParser.Report.value(field, 50)     #=> 50
HidParser.Report.physical(field, 50)  #=> 500.0
HidParser.Report.scaled(field, 50)    #=> 50.0
```

Because scaling is an accessor, not storage, the encode path always takes
logical integers: `build/2` is unaffected by physical ranges or units.

---

# Convenience values

`to_keyword/2` flattens canonical values into a list with **one entry per
element**, always — a count-N field yields N entries and a shared usage is
repeated N times:

```elixir
HidParser.Report.to_keyword(report, values)
# [
#   {"Keyboard LeftControl", %{usage_page: 7, usage_id: 0xE0, value: 1}},
#   {"Keyboard LeftShift",   %{usage_page: 7, usage_id: 0xE1, value: 0}},
#   {"Keyboard A",           %{usage_page: 7, usage_id: 0x04, value: 0x04}},
#   {"Keyboard 1 and Bang",  %{usage_page: 7, usage_id: 0x1E, value: 0x1E}}
# ]
```

Each entry is `{usage_name, %{usage_page:, usage_id:, value:}}`. The key is the
usage **name** string; when the id is absent from the usage tables it falls back
to `"0xpage:0xusage"`. This layer is opt-in and lossy only when usages collide —
the canonical layer remains the source of truth.

---

# Roundtrip guarantees and edge cases

The model is built for a clean roundtrip:

- `parse(build(values)) == values`
- `build(parse(binary)) == binary` — for binaries whose constant bits are zero

Edge cases to be aware of:

- **Bit packing** — fields are packed LSB-first in field order; a count-N field
  contributes N consecutive values of `size` bits each.
- **Signedness** — a field is signed iff `logical_min < 0`; the codec branches on
  `signed?`.
- **Report ID** — when the descriptor uses `ReportId`, the first byte of every
  report is the id and the model keys reports by id.
- **Constant/padding fields** roundtrip as *zero* bits. A device that pads with
  non-zero constant bits will not roundtrip bit-exactly (documented corner).
- **Collections** — field offsets are computed across collection boundaries
  (nesting does not reset the bit cursor); collection usages apply to contained
  fields that declare none.

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
are absent, so `mix test` stays green offline. hid-tools embeds descriptors as
Python byte arrays but ships no raw report recordings, so roundtrip is validated
against synthesized reports rather than recorded ones.

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
- [DESIGN.md](DESIGN.md) — the report-model design and its resolved decisions
