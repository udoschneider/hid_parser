defmodule Mix.Tasks.HidParser.FetchFixtures do
  @moduledoc """
  Fetches pinned HID report descriptors from `hid-tools` into `test/fixtures/`.

  The report model's fixture-backed tests roundtrip real-world descriptors
  instead of hand-built ones. Those descriptors are **not vendored**: hid-tools
  (gitlab.freedesktop.org/libevdev/hid-tools, GPL-2.0) is the canonical source
  of real report descriptors. We fetch a few pinned source files at test time,
  never commit/ship them — the GPL triggers on distribution, not use, so
  fetching at test time is fine.

  Each pinned file embeds one or more `report_descriptor = [...]` byte arrays
  that the fixture test extracts. The chosen files cover the target cases:
  keyboard (array + report id + constant padding), physical scaling, signed
  axes, multiple report ids and collection usage inheritance.

  Runs on demand (`mix hid_parser.fetch_fixtures`); use `--force` to re-fetch.
  """

  use Mix.Task

  @shortdoc "Fetches pinned hid-tools report descriptors for tests"

  @commit "f4a32530ea548df2ae5efd2ebfd16d4c3e658875"

  @url_base "https://gitlab.freedesktop.org/libevdev/hid-tools/-/raw/#{@commit}/tests_kernel/"

  @files [
    "test_keyboard.py",
    "test_mouse.py",
    "test_gamepad.py",
    "test_wacom_generic.py"
  ]

  @target_dir Path.expand("../../../test/fixtures", __DIR__)

  @impl Mix.Task
  def run(args) do
    File.mkdir_p!(@target_dir)

    for file <- @files do
      target = Path.join(@target_dir, file)

      if "--force" in args or not File.exists?(target) do
        fetch!(file, target)
      else
        Mix.shell().info("fixture #{file} already present; use --force to re-fetch")
      end
    end
  end

  defp fetch!(file, target) do
    Mix.shell().info("Fetching fixture #{file}")

    {output, status} =
      System.cmd(
        "curl",
        [
          "--fail",
          "--silent",
          "--show-error",
          "--location",
          "--output",
          target,
          @url_base <> file
        ],
        stderr_to_stdout: true
      )

    if status != 0 do
      Mix.raise("Failed to download fixture #{file} (curl exit #{status}):\n#{output}")
    end
  end
end
