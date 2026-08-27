defmodule HidParser.ReportDescriptor.UsagePageParser do
  @moduledoc """
  Parses the HID Usage Tables JSON into a lookup map.

  The JSON is fetched at build time by `Mix.Tasks.HidParser.FetchUsageTables`
  (see that module for provenance) and read lazily by
  `HidParser.ReportDescriptor.usage_pages/0`.
  """

  @doc """
  Parses the usage tables JSON file at `path` into `%{page_id => page}`.
  """
  @spec parse(Path.t()) :: map()
  def parse(path) do
    path
    |> File.read!()
    |> JSON.decode!()
    |> Map.get("UsagePages")
    |> parse_usage_pages()
  end

  defp parse_usage_pages(pages) do
    pages
    |> Enum.map(fn page -> {Map.get(page, "Id"), parse_usage_page(page)} end)
    |> Enum.into(%{})
  end

  defp parse_usage_page(page) do
    %{
      kind: Map.get(page, "Kind"),
      name: Map.get(page, "Name"),
      usage_ids: Map.get(page, "UsageIds") |> parse_usage_ids()
    }
  end

  defp parse_usage_ids(ids) do
    ids
    |> Enum.map(fn id -> {Map.get(id, "Id"), parse_usage_id(id)} end)
    |> Enum.into(%{})
  end

  defp parse_usage_id(id) do
    %{kinds: Map.get(id, "Kinds"), name: Map.get(id, "Name")}
  end
end
