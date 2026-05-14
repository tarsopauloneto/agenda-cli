defmodule AgendaCli do
  @moduledoc """
  CLI simples da agenda.
  """

  alias AgendaCli.Contacts
  alias AgendaCli.Store

  @contact_flags %{
    "--name" => :name,
    "--company" => :company,
    "--phone" => :phone,
    "--email" => :email
  }

  @search_flags %{
    "--name" => :name,
    "--phone" => :phone,
    "--email" => :email
  }

  def main(_args) do
    Store.load()
    |> loop()
  end

  defp loop(contacts) do
    case IO.gets("agenda> ") do
      :eof ->
        :ok

      {:error, reason} ->
        IO.puts("Erro de entrada: #{inspect(reason)}")
        loop(contacts)

      input ->
        case execute_command(parse_command(input), contacts) do
          {:exit, _contacts} ->
            :ok

          {next_contacts, messages, save?} ->
            Enum.each(messages, &IO.puts/1)

            if save? do
              save_contacts(next_contacts)
            end

            loop(next_contacts)
        end
    end
  end

  def parse_command(input) do
    case input |> String.trim() |> String.split() do
      [] -> :empty
      ["exit"] -> :exit
      ["list"] -> :list
      ["show", id] -> parse_id_command(:show, id)
      ["del", id] -> parse_id_command(:del, id)
      ["add" | tokens] -> parse_add(tokens)
      ["edit" | tokens] -> parse_edit(tokens)
      ["search" | tokens] -> parse_search(tokens)
      _ -> {:error, :unknown_command}
    end
  end

  def parse_add(tokens) do
    case parse_fields(tokens, @contact_flags) do
      :error -> {:error, :invalid_command}
      attributes -> {:add, attributes}
    end
  end

  def parse_edit([id | tokens]) do
    case {parse_id(id), parse_fields(tokens, @contact_flags)} do
      {{:ok, contact_id}, attributes} when attributes != %{} and attributes != :error ->
        {:edit, contact_id, attributes}

      _ ->
        {:error, :invalid_command}
    end
  end

  def parse_edit(_tokens), do: {:error, :invalid_command}

  def parse_search(tokens) do
    case parse_fields(tokens, @search_flags) do
      attributes when is_map(attributes) ->
        case Map.to_list(attributes) do
          [{field, value}] when field in [:name, :phone, :email] ->
            {:search, {field, value}}

          _ ->
            {:error, :invalid_command}
        end

      _ ->
        {:error, :invalid_command}
    end
  end

  def execute_command(:empty, contacts), do: {contacts, [], false}
  def execute_command(:exit, contacts), do: {:exit, contacts}

  def execute_command(:list, contacts) do
    {contacts, [format_contacts(contacts)], false}
  end

  def execute_command({:show, contact_id}, contacts) do
    case Contacts.get_contact(contacts, contact_id) do
      nil -> {contacts, ["Contato nao encontrado."], false}
      contact -> {contacts, [format_contact(contact)], false}
    end
  end

  def execute_command({:search, filter}, contacts) do
    results = Contacts.search_contacts(contacts, filter)
    {contacts, [format_search_results(results)], false}
  end

  def execute_command({:add, attributes}, contacts) do
    case Contacts.validate_new_contact(attributes) do
      :ok ->
        updated_contacts = Contacts.add_contact(contacts, attributes)
        {updated_contacts, ["Contato adicionado com sucesso."], true}

      {:error, messages} ->
        {contacts, messages, false}
    end
  end

  def execute_command({:edit, contact_id, attributes}, contacts) do
    case Contacts.get_contact(contacts, contact_id) do
      nil ->
        {contacts, ["Contato nao encontrado."], false}

      _contact ->
        case Contacts.validate_contact_updates(attributes) do
          :ok ->
            updated_contacts = Contacts.edit_contact(contacts, contact_id, attributes)
            {updated_contacts, ["Contato atualizado com sucesso."], true}

          {:error, messages} ->
            {contacts, messages, false}
        end
    end
  end

  def execute_command({:del, contact_id}, contacts) do
    case Contacts.get_contact(contacts, contact_id) do
      nil ->
        {contacts, ["Contato nao encontrado."], false}

      _contact ->
        updated_contacts = Contacts.delete_contact(contacts, contact_id)
        {updated_contacts, ["Contato removido com sucesso."], true}
    end
  end

  def execute_command({:error, :invalid_command}, contacts) do
    {contacts, ["Comando invalido."], false}
  end

  def execute_command({:error, :unknown_command}, contacts) do
    {contacts, ["Comando desconhecido."], false}
  end

  defp parse_id_command(command, value) do
    case parse_id(value) do
      {:ok, id} -> {command, id}
      :error -> {:error, :invalid_command}
    end
  end

  defp parse_id(value) do
    case Integer.parse(value) do
      {id, ""} -> {:ok, id}
      _ -> :error
    end
  end

  defp parse_fields([], _allowed_flags), do: %{}

  defp parse_fields([flag | tokens], allowed_flags) do
    case Map.fetch(allowed_flags, flag) do
      {:ok, field} ->
        {value_tokens, rest} = Enum.split_while(tokens, &(not flag?(&1)))

        if value_tokens == [] do
          :error
        else
          case parse_fields(rest, allowed_flags) do
            :error -> :error
            attributes -> Map.put(attributes, field, Enum.join(value_tokens, " "))
          end
        end

      :error ->
        :error
    end
  end

  defp flag?(token), do: String.starts_with?(token, "--")

  defp save_contacts(contacts) do
    case Store.save(contacts) do
      :ok -> :ok
      {:error, reason} -> IO.puts("Erro ao salvar contatos: #{inspect(reason)}")
    end
  end

  defp format_contacts([]), do: "Nenhum contato cadastrado."

  defp format_contacts(contacts) do
    ["id | nome | empresa | telefone | email" | Enum.map(contacts, &format_contact_row/1)]
    |> Enum.join("\n")
  end

  defp format_search_results([]), do: "Nenhum contato encontrado."
  defp format_search_results(contacts), do: format_contacts(contacts)

  defp format_contact_row(contact) do
    [
      Map.get(contact, "id"),
      Map.get(contact, "name", ""),
      Map.get(contact, "company", ""),
      Map.get(contact, "phone", ""),
      Map.get(contact, "email", "")
    ]
    |> Enum.map(&to_string/1)
    |> Enum.join(" | ")
  end

  defp format_contact(contact) do
    [
      "id: #{Map.get(contact, "id")}",
      "nome: #{Map.get(contact, "name", "")}",
      "empresa: #{Map.get(contact, "company", "")}",
      "telefone: #{Map.get(contact, "phone", "")}",
      "email: #{Map.get(contact, "email", "")}"
    ]
    |> Enum.join("\n")
  end
end
