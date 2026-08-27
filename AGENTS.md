# AGENTS.md

Elixir library that parses USB HID report descriptors (HID 1.11 spec) into structured items.

## Architecture

- Entry point: `HidParser.parse_report_descriptor/1` (`lib/hid_parser.ex`) → `HidParser.ReportDescriptor.parse_items/1` (`lib/hid_parser/report_descriptor.ex`).
- One module per descriptor item type under `HidParser.ReportDescriptor.*` (e.g. `Input`, `Usage`, `LogicalMaximum`, `Collection`). Item tag/bits are decoded in `report_descriptor.ex`'s `new_item/4`.
- Struct field convention (verify against `lib/hid_parser/report_descriptor/*.ex` before adding a new item):
  - Global/Local items → `value` (integer)
  - Main items (`Input`/`Output`/`Feature`) → `flags` (integer)
  - `Collection` → `flags`, `items` (list), `end_flags`
  - `Reserved` → `raw` (binary)
- `parse_items/1` returns a **flat** list. The `parse_collections/1` function that builds the nested collection tree exists but is **private** and not exposed.

## Gotchas

- Usage tables (`priv/static/HidUsageTables.json`) are parsed at **compile time** into the `@usage_pages` attribute using `HidParser.ReportDescriptor.UsagePageParser` (which uses the native `JSON` module, Elixir 1.18+), exposed via `usage_pages/0`.
- `parse_collections/1` (builds the nested collection tree) and `parse_collections/2` are private/unused, so compilation emits an "unused function" warning — expected.

## Toolchain

- Elixir/Erlang are pinned via mise (`mise.toml`): Elixir `1.20.3-otp-29`, OTP `29.0.5`. `mix.exs` requires `elixir: "~> 1.20"`.
- No JSON dependency: the code uses the native `JSON` module (no `jason` in `mix.exs`).

## Conventions

- Commit messages follow the [Conventional Commits](https://www.conventionalcommits.org/) format (e.g. `feat:`, `fix:`, `refactor:`, `chore:`).

## Commands

- `mix test` — ExUnit; tests build raw binaries inline (no fixtures). Doctests are used.
- `mix format` — standard inputs in `.formatter.exs`.
- `mix check` — curated checks via `ex_check` (`.check.exs`).
- `mix credo`, `mix dialyzer`, `mix doctor`, `mix docs` — other dev tools; `doctor` requires moduledocs (`.doctor.exs`).

## Reference

- `notes.md` — HID spec links and the `usbhid-dump`/`hidrd` capture workflow.
- `hids/` — sample Cherry keyboard descriptor dump (`cherry_keyboard.hid.{bin,spec,c}`) used for manual testing.
