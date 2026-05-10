defmodule AgendaCli do
  @moduledoc """
  Ponto de entrada da CLI da agenda.
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

  @spec main([String.t()]) :: :ok
  def main(_args) do
    state = %{
      contacts: Store.load()
    }

    loop(state)
  end

  defp loop(state) do
    case IO.gets("agenda> ") do
      :eof ->
        :ok

      {:error, reason} ->
        IO.puts("Erro de entrada: #{inspect(reason)}")
        loop(state)

      input ->
        input
        |> parse_command()
        |> handle_command(state)
    end
  end

  @type command_result ::
          {:continue, state(), messages(), :noop | :save}
          | {:stop, state(), messages()}
  @type parsed_command ::
          :empty
          | :exit
          | :list
          | {:add, map()}
          | {:edit, integer(), map()}
          | {:del, integer()}
          | {:show, integer()}
          | {:search, {:name | :phone | :email, String.t()}}
          | {:error, :invalid_command | :unknown_command}
  @type state :: %{contacts: Contacts.t()}
  @type messages :: [String.t()]

  @spec parse_command(String.t()) :: parsed_command()
  def parse_command(input) do
    input
    |> String.trim()
    |> String.split()
    |> parse_tokens()
  end

  @spec execute_command(parsed_command(), state()) :: command_result()
  def execute_command(:exit, state), do: {:stop, state, []}

  def execute_command(:empty, state), do: {:continue, state, [], :noop}

  def execute_command(:list, %{contacts: contacts} = state) do
    continue(state, [format_contacts_list(contacts)])
  end

  def execute_command({:show, contact_id}, state) do
    state
    |> find_contact(contact_id)
    |> show_contact_result(state)
  end

  def execute_command({:search, filter}, %{contacts: contacts} = state) do
    contacts
    |> Contacts.search_contacts(filter)
    |> format_search_results()
    |> then(&continue(state, [&1]))
  end

  def execute_command({:add, attributes}, state) do
    validate(:new_contact, attributes)
    |> add_contact_result(state, attributes)
  end

  def execute_command({:edit, contact_id, attributes}, state) do
    state
    |> find_contact(contact_id)
    |> edit_contact_result(state, contact_id, attributes)
  end

  def execute_command({:del, contact_id}, %{contacts: contacts} = state) do
    case Contacts.get_contact(contacts, contact_id) do
      nil -> continue(state, ["Contato nao encontrado."])

      _contact ->
        persist_contacts(
          state,
          Contacts.delete_contact(contacts, contact_id),
          "Contato removido com sucesso."
        )
    end
  end

  def execute_command({:error, :invalid_command}, state), do: continue(state, ["Comando invalido."])

  def execute_command({:error, :unknown_command}, state), do: continue(state, ["Comando desconhecido."])

  @spec parse_add([String.t()]) :: {:add, map()} | {:error, :invalid_command}
  def parse_add(tokens) do
    case parse_flags(tokens, @contact_flags) do
      {:ok, attributes} when map_size(attributes) > 0 -> {:add, attributes}
      _ -> {:error, :invalid_command}
    end
  end

  @spec parse_edit([String.t()]) :: {:edit, integer(), map()} | {:error, :invalid_command}
  def parse_edit([contact_id | tokens]) do
    with {:ok, id} <- parse_id(contact_id),
         {:ok, attributes} <- parse_flags(tokens, @contact_flags),
         true <- map_size(attributes) > 0 do
      {:edit, id, attributes}
    else
      _ -> {:error, :invalid_command}
    end
  end

  def parse_edit(_tokens), do: {:error, :invalid_command}

  @spec parse_search([String.t()]) ::
          {:search, {:name | :phone | :email, String.t()}} | {:error, :invalid_command}
  def parse_search(tokens) do
    with {:ok, attributes} <- parse_flags(tokens, @search_flags),
         {:ok, filter} <- build_search_filter(attributes) do
      {:search, filter}
    else
      _ -> {:error, :invalid_command}
    end
  end

  defp parse_tokens([]), do: :empty
  defp parse_tokens(["exit"]), do: :exit
  defp parse_tokens(["list"]), do: :list
  defp parse_tokens(["add" | tokens]), do: parse_add(tokens)
  defp parse_tokens(["edit" | tokens]), do: parse_edit(tokens)
  defp parse_tokens(["search" | tokens]), do: parse_search(tokens)
  defp parse_tokens(["del", contact_id]), do: parse_id_command(:del, contact_id)
  defp parse_tokens(["show", contact_id]), do: parse_id_command(:show, contact_id)
  defp parse_tokens(_tokens), do: {:error, :unknown_command}

  defp handle_command(command, state) do
    case execute_command(command, state) do
      {:stop, _next_state, messages} ->
        state
        |> print_output(messages)

        :ok

      {:continue, next_state, messages, save_action} ->
        next_state
        |> maybe_save_contacts(save_action)
        |> print_output(messages)
        |> loop()
    end
  end

  defp parse_id_command(command, value) do
    case parse_id(value) do
      {:ok, contact_id} -> {command, contact_id}
      :error -> {:error, :invalid_command}
    end
  end

  defp parse_id(value) do
    case Integer.parse(value) do
      {contact_id, ""} -> {:ok, contact_id}
      _ -> :error
    end
  end

  defp parse_flags(tokens, allowed_flags) do
    tokens
    |> do_parse_flags(allowed_flags, %{})
  end

  defp do_parse_flags([], _allowed_flags, attributes), do: {:ok, attributes}

  defp do_parse_flags([flag | tokens], allowed_flags, attributes) do
    case Map.fetch(allowed_flags, flag) do
      {:ok, field} ->
        case take_flag_value(tokens, []) do
          {[], _remaining_tokens} ->
            {:error, :invalid_command}

          {value_tokens, remaining_tokens} ->
            updated_attributes = Map.put(attributes, field, Enum.join(value_tokens, " "))
            do_parse_flags(remaining_tokens, allowed_flags, updated_attributes)
        end

      :error ->
        {:error, :invalid_command}
    end
  end

  defp take_flag_value([], values), do: {Enum.reverse(values), []}

  defp take_flag_value([token | tokens], values) do
    case flag_token?(token) do
      true -> {Enum.reverse(values), [token | tokens]}
      false -> take_flag_value(tokens, [token | values])
    end
  end

  defp build_search_filter(attributes) do
    case Enum.to_list(attributes) do
      [{field, value}] -> {:ok, {field, value}}
      _ -> {:error, :invalid_command}
    end
  end

  defp flag_token?("--" <> _rest), do: true
  defp flag_token?(_token), do: false

  defp continue(state, messages), do: {:continue, state, messages, :noop}

  defp persist_contacts(state, contacts, message) do
    {:continue, %{state | contacts: contacts}, [message], :save}
  end

  defp find_contact(%{contacts: contacts}, contact_id) do
    case Contacts.get_contact(contacts, contact_id) do
      nil -> :not_found
      contact -> {:ok, contact}
    end
  end

  defp show_contact_result(:not_found, state), do: continue(state, ["Contato nao encontrado."])

  defp show_contact_result({:ok, contact}, state) do
    continue(state, [format_contact_details(contact)])
  end

  defp add_contact_result(:ok, %{contacts: contacts} = state, attributes) do
    state
    |> persist_contacts(Contacts.add_contact(contacts, attributes), "Contato adicionado com sucesso.")
  end

  defp add_contact_result({:error, messages}, state, _attributes), do: continue(state, messages)

  defp edit_contact_result(:not_found, state, _contact_id, _attributes) do
    continue(state, ["Contato nao encontrado."])
  end

  defp edit_contact_result({:ok, _contact}, %{contacts: contacts} = state, contact_id, attributes) do
    validate(:contact_updates, attributes)
    |> persist_edited_contact(state, contacts, contact_id, attributes)
  end

  defp persist_edited_contact(:ok, state, contacts, contact_id, attributes) do
    state
    |> persist_contacts(
      Contacts.edit_contact(contacts, contact_id, attributes),
      "Contato atualizado com sucesso."
    )
  end

  defp persist_edited_contact({:error, messages}, state, _contacts, _contact_id, _attributes) do
    continue(state, messages)
  end

  defp validate(:new_contact, attributes), do: Contacts.validate_new_contact(attributes)
  defp validate(:contact_updates, attributes), do: Contacts.validate_contact_updates(attributes)

  defp maybe_save_contacts(state, :noop), do: state

  defp maybe_save_contacts(%{contacts: contacts} = state, :save) do
    case Store.save(contacts) do
      :ok ->
        state

      {:error, reason} ->
        IO.puts("Erro ao salvar contatos: #{inspect(reason)}")
        state
    end
  end

  defp print_output(state, []), do: state

  defp print_output(state, messages) do
    messages
    |> Enum.each(&IO.puts/1)

    state
  end

  defp format_contacts_list([]), do: "Nenhum contato cadastrado."

  defp format_contacts_list(contacts) do
    ["id | nome | empresa | telefone | email" | Enum.map(contacts, &format_contact_row/1)]
    |> Enum.join("\n")
  end

  defp format_search_results([]), do: "Nenhum contato encontrado."
  defp format_search_results(contacts), do: format_contacts_list(contacts)

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

  defp format_contact_details(contact) do
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
