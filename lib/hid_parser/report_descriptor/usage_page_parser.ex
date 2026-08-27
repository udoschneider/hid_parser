defmodule HidParser.ReportDescriptor.UsagePageParser do
  # Parse the JSON file extracted from https://usb.org/document-library/hid-usage-tables-14 into something more usable

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
