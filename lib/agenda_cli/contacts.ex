defmodule AgendaCli.Contacts do
  @moduledoc """
  Funcoes puras para manipular a lista de contatos.
  """

  @allowed_fields ~w(name company phone email)
  @searchable_fields %{
    name: "name",
    phone: "phone",
    email: "email"
  }
  @required_fields @allowed_fields
  @field_labels %{
    "name" => "Nome",
    "company" => "Empresa",
    "phone" => "Telefone",
    "email" => "Email"
  }

  @type contact :: %{
          required(String.t()) => String.t() | integer()
        }
  @type t :: [contact()]
  @type search_filter :: {:name | :phone | :email, String.t()}

  @spec new() :: t()
  def new, do: []

  @spec validate_new_contact(map()) :: :ok | {:error, [String.t()]}
  def validate_new_contact(attributes) when is_map(attributes) do
    attributes
    |> normalize_contact_attributes()
    |> validate_required_contact()
  end

  @spec validate_contact_updates(map()) :: :ok | {:error, [String.t()]}
  def validate_contact_updates(attributes) when is_map(attributes) do
    attributes
    |> normalize_contact_attributes()
    |> validate_partial_contact()
  end

  @spec add_contact(t(), map()) :: t()
  def add_contact(contacts, attributes) when is_list(contacts) and is_map(attributes) do
    attributes
    |> normalize_contact_attributes()
    |> build_contact()
    |> then(&Enum.concat(contacts, [&1]))
  end

  @spec delete_contact(t(), integer()) :: t()
  def delete_contact(contacts, contact_id) when is_list(contacts) do
    contacts
    |> Enum.reject(&match_contact_id?(&1, contact_id))
  end

  @spec get_contact(t(), integer()) :: contact() | nil
  def get_contact(contacts, contact_id) when is_list(contacts) do
    contacts
    |> Enum.find(&match_contact_id?(&1, contact_id))
  end

  @spec list_contacts(t()) :: t()
  def list_contacts(contacts) when is_list(contacts), do: contacts

  @spec search_contacts(t(), search_filter()) :: t()
  def search_contacts(contacts, {field, value}) when is_list(contacts) do
    contacts
    |> search_by_field(search_field(field), value)
  end

  @spec edit_contact(t(), integer(), map()) :: t()
  def edit_contact(contacts, contact_id, attributes)
      when is_list(contacts) and is_map(attributes) do
    updates = normalize_contact_attributes(attributes)

    contacts
    |> Enum.map(fn
      %{"id" => id} = contact when id == contact_id ->
        Map.merge(contact, updates)

      contact ->
        contact
    end)
  end

  defp search_by_field(contacts, field, value) do
    normalized_query = normalize_search_value(value)

    contacts
    |> Enum.filter(fn contact ->
      contact
      |> Map.get(field, "")
      |> normalize_search_value()
      |> String.contains?(normalized_query)
    end)
  end

  defp normalize_contact_attributes(attributes) do
    attributes
    |> Enum.reduce(%{}, fn
      {"id", _value}, acc ->
        acc

      {:id, _value}, acc ->
        acc

      {key, value}, acc ->
        normalized_key = to_string(key)

        if normalized_key in @allowed_fields do
          Map.put(acc, normalized_key, value)
        else
          acc
        end
    end)
  end

  defp normalize_search_value(value) do
    value
    |> to_string()
    |> String.downcase()
  end

  defp build_contact(attributes) do
    Map.put(attributes, "id", System.system_time(:millisecond))
  end

  defp match_contact_id?(%{"id" => id}, contact_id), do: id == contact_id

  defp search_field(field), do: Map.fetch!(@searchable_fields, field)

  defp validate_required_contact(attributes) do
    attributes
    |> blank_field_errors(@required_fields)
    |> Kernel.++(validate_shared_rules(attributes))
    |> format_validation_result()
  end

  defp validate_partial_contact(attributes) do
    blank_field_errors(attributes, Map.keys(attributes))
    |> Kernel.++(validate_shared_rules(attributes))
    |> format_validation_result()
  end

  defp validate_shared_rules(attributes) do
    validate_email(attributes) ++ validate_phone(attributes)
  end

  defp validate_email(%{"email" => email}) do
    case String.contains?(to_string(email), "@") do
      true -> []
      false -> ["Email deve conter @."]
    end
  end

  defp validate_email(_attributes), do: []

  defp validate_phone(%{"phone" => phone}) do
    phone_as_text = to_string(phone)

    []
    |> maybe_add_phone_digits_error(phone_as_text)
    |> maybe_add_phone_length_error(phone_as_text)
  end

  defp validate_phone(_attributes), do: []

  defp maybe_add_phone_digits_error(errors, phone) do
    case String.match?(phone, ~r/^\d+$/) do
      true -> errors
      false -> errors ++ ["Telefone deve conter apenas numeros."]
    end
  end

  defp maybe_add_phone_length_error(errors, phone) do
    case String.length(phone) >= 10 do
      true -> errors
      false -> errors ++ ["Telefone deve ter pelo menos 10 digitos."]
    end
  end

  defp format_validation_result([]), do: :ok
  defp format_validation_result(errors), do: {:error, errors}

  defp blank_field_errors(attributes, fields) when is_list(fields) do
    fields
    |> Enum.reduce([], fn field, errors ->
      case valid_text_field?(Map.get(attributes, field)) do
        true -> errors
        false -> ["#{field_label(field)} nao pode ficar vazio." | errors]
      end
    end)
    |> Enum.reverse()
  end

  defp valid_text_field?(nil), do: false

  defp valid_text_field?(value) do
    value
    |> to_string()
    |> String.trim()
    |> Kernel.!=("")
  end

  defp field_label(field), do: Map.fetch!(@field_labels, field)
end
