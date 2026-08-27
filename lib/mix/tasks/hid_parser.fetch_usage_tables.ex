defmodule Mix.Tasks.HidParser.FetchUsageTables do
  @moduledoc """
  Fetches the HID Usage Tables JSON into `priv/static/HidUsageTables.json`.

  USB-IF publishes the HID Usage Tables only as a PDF (`hut1_*.pdf`) with the
  JSON embedded as an attachment, so there is no standalone download URL. We
  mirror the extracted JSON from a pinned commit of `microsoft/mu_rust_hid`
  (an unmodified copy of the official file) instead of extracting it from the
  PDF at build time.

  The downloaded file is verified against a pinned SHA-256 (`@sha256`) before it
  is used, so a tampered or truncated mirror is rejected rather than compiled
  in. The file is fetched once and reused on subsequent builds, so `mix compile`
  only needs network on a fresh checkout.

  Runs automatically before `mix compile`. Use `--force` to re-fetch.
  """

  use Mix.Task

  @shortdoc "Fetches the HID Usage Tables JSON"

  @usage_tables_url "https://raw.githubusercontent.com/microsoft/mu_rust_hid/" <>
                      "23283fc00647cbf204fc72d5bc83a837cf58c42c/" <>
                      "examples/resources/HidUsageTables.json"

  @sha256 "127ebe3c81a8c82f5541a833200de562558add95c423363dc0e9a795bb70b418"

  @target_path Path.expand("../../../priv/static/HidUsageTables.json", __DIR__)

  @impl Mix.Task
  def run(args) do
    if "--force" in args or not File.exists?(@target_path) do
      fetch!()
    else
      Mix.shell().info("HID Usage Tables already present; use --force to re-fetch")
    end
  end

  defp fetch! do
    Mix.shell().info("Fetching HID Usage Tables (HidUsageTables.json)")

    File.mkdir_p!(Path.dirname(@target_path))

    {output, status} =
      System.cmd(
        "curl",
        [
          "--fail",
          "--silent",
          "--show-error",
          "--location",
          "--output",
          @target_path,
          @usage_tables_url
        ],
        stderr_to_stdout: true
      )

    if status != 0 do
      Mix.raise("Failed to download HID Usage Tables (curl exit #{status}):\n#{output}")
    end

    verify_checksum!()
  end

  defp verify_checksum! do
    actual =
      @target_path
      |> File.read!()
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    if actual != @sha256 do
      Mix.raise(
        "HID Usage Tables checksum mismatch: expected #{@sha256}, got #{actual}; " <>
          "refusing to use the downloaded file"
      )
    end
  end
end
