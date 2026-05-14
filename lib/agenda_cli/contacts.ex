defmodule AgendaCli.Contacts do
  @moduledoc """
  Funcoes puras para manipular contatos.
  """

  @fields ~w(name company phone email)

  def new, do: []

  def add_contact(contacts, attributes) do
    contact =
      attributes
      |> normalize_attributes()
      |> Map.put("id", System.unique_integer([:positive]))

    contacts ++ [contact]
  end

  def get_contact(contacts, contact_id) do
    Enum.find(contacts, fn contact -> contact["id"] == contact_id end)
  end

  def list_contacts(contacts), do: contacts

  def search_contacts(contacts, {field, value}) do
    field = Atom.to_string(field)
    value = value |> to_string() |> String.downcase()

    Enum.filter(contacts, fn contact ->
      contact
      |> Map.get(field, "")
      |> String.downcase()
      |> String.contains?(value)
    end)
  end

  def edit_contact(contacts, contact_id, attributes) do
    updates = normalize_attributes(attributes)

    Enum.map(contacts, fn
      %{"id" => ^contact_id} = contact -> Map.merge(contact, updates)
      contact -> contact
    end)
  end

  def delete_contact(contacts, contact_id) do
    Enum.reject(contacts, fn contact -> contact["id"] == contact_id end)
  end

  def validate_new_contact(attributes) do
    attributes = normalize_attributes(attributes)

    errors =
      []
      |> required_field_error(attributes, "name", "Nome")
      |> required_field_error(attributes, "company", "Empresa")
      |> required_field_error(attributes, "phone", "Telefone")
      |> required_field_error(attributes, "email", "Email")
      |> Kernel.++(validate_email(attributes))
      |> Kernel.++(validate_phone(attributes))

    if errors == [], do: :ok, else: {:error, errors}
  end

  def validate_contact_updates(attributes) do
    attributes = normalize_attributes(attributes)

    errors =
      Enum.reduce(Map.keys(attributes), [], fn field, acc ->
        if blank?(Map.get(attributes, field)) do
          acc ++ ["#{field_label(field)} nao pode ficar vazio."]
        else
          acc
        end
      end) ++ validate_email(attributes) ++ validate_phone(attributes)

    if errors == [], do: :ok, else: {:error, errors}
  end

  defp normalize_attributes(attributes) do
    Enum.reduce(attributes, %{}, fn {key, value}, acc ->
      key = to_string(key)

      if key in @fields do
        Map.put(acc, key, to_string(value))
      else
        acc
      end
    end)
  end

  defp required_field_error(errors, attributes, field, label) do
    if blank?(Map.get(attributes, field)) do
      errors ++ ["#{label} nao pode ficar vazio."]
    else
      errors
    end
  end

  defp validate_email(%{"email" => email}) do
    if String.contains?(email, "@"), do: [], else: ["Email deve conter @."]
  end

  defp validate_email(_attributes), do: []

  defp validate_phone(%{"phone" => phone}) do
    errors = []

    errors =
      if String.match?(phone, ~r/^\d+$/) do
        errors
      else
        errors ++ ["Telefone deve conter apenas numeros."]
      end

    if String.length(phone) >= 10 do
      errors
    else
      errors ++ ["Telefone deve ter pelo menos 10 digitos."]
    end
  end

  defp validate_phone(_attributes), do: []

  defp blank?(value) do
    value == nil or String.trim(to_string(value)) == ""
  end

  defp field_label("name"), do: "Nome"
  defp field_label("company"), do: "Empresa"
  defp field_label("phone"), do: "Telefone"
  defp field_label("email"), do: "Email"
end
