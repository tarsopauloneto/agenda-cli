defmodule AgendaCli.Store do
  @moduledoc """
  Persistencia de contatos em arquivo JSON.
  """

  @contacts_file "contacts.json"
  @serializer Jason

  @type contact :: map()
  @type contacts :: [contact()]

  @spec load() :: contacts()
  def load do
    @contacts_file
    |> read_contacts_file()
    |> decode_contacts()
  end

  @spec save(contacts()) :: :ok | {:error, File.posix()}
  def save(contacts) when is_list(contacts) do
    contacts
    |> encode_contacts()
    |> write_contacts_file()
  end

  defp read_contacts_file(path) do
    case File.read(path) do
      {:ok, contents} -> contents
      {:error, _reason} -> nil
    end
  end

  defp decode_contacts(nil), do: []

  defp decode_contacts(contents) do
    case @serializer.decode(contents) do
      {:ok, contacts} when is_list(contacts) -> contacts
      _ -> []
    end
  end

  defp encode_contacts(contacts) do
    @serializer.encode_to_iodata!(contacts, pretty: true)
  end

  defp write_contacts_file(contents) do
    File.write(@contacts_file, [contents, ?\n])
  end
end
