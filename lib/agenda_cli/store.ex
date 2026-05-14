defmodule AgendaCli.Store do
  @moduledoc """
  Persistencia simples em JSON.
  """

  @contacts_file "contacts.json"

  def load do
    case File.read(@contacts_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, contacts} when is_list(contacts) -> contacts
          _ -> []
        end

      {:error, _reason} ->
        []
    end
  end

  def save(contacts) do
    json = Jason.encode_to_iodata!(contacts, pretty: true)
    File.write(@contacts_file, [json, ?\n])
  end
end
