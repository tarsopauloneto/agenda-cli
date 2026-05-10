defmodule AgendaCli.StoreTest do
  use ExUnit.Case

  alias AgendaCli.Store

  setup do
    tmp_dir =
      Path.join(
        System.tmp_dir!(),
        "agenda_cli_store_test_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    {:ok, tmp_dir: tmp_dir}
  end

  test "load/0 returns an empty list when the file does not exist", %{tmp_dir: tmp_dir} do
    File.cd!(tmp_dir, fn ->
      assert Store.load() == []
    end)
  end

  test "load/0 returns an empty list when the json is invalid", %{tmp_dir: tmp_dir} do
    File.cd!(tmp_dir, fn ->
      File.write!("contacts.json", "{invalid json}")

      assert Store.load() == []
    end)
  end

  test "save/1 overwrites the file and load/0 returns the saved contacts", %{tmp_dir: tmp_dir} do
    contacts = [
      %{
        "id" => 1_713_531_600_000,
        "name" => "Ana Lima",
        "company" => "Acme Ltda",
        "phone" => "85912345678",
        "email" => "ana.lima@acme.com"
      }
    ]

    File.cd!(tmp_dir, fn ->
      File.write!("contacts.json", ~s([{"old":"data"}]))

      assert Store.save(contacts) == :ok
      assert Store.load() == contacts
      assert Jason.decode!(File.read!("contacts.json")) == contacts
    end)
  end
end

defmodule AgendaCli.ContactsTest do
  use ExUnit.Case

  alias AgendaCli.Contacts

  test "add_contact/2 adds a new contact with generated id" do
    contacts =
      Contacts.add_contact([], %{
        name: "Ana Lima",
        company: "Acme Ltda",
        phone: "85912345678",
        email: "ana.lima@acme.com"
      })

    assert [
             %{
               "id" => id,
               "name" => "Ana Lima",
               "company" => "Acme Ltda",
               "phone" => "85912345678",
               "email" => "ana.lima@acme.com"
             }
           ] = contacts

    assert is_integer(id)
  end

  test "get_contact/2 returns the contact by id" do
    contacts = sample_contacts()

    assert Contacts.get_contact(contacts, 2)["name"] == "Bruno Costa"
    assert Contacts.get_contact(contacts, 999) == nil
  end

  test "list_contacts/1 returns the full list" do
    contacts = sample_contacts()

    assert Contacts.list_contacts(contacts) == contacts
  end

  test "search_contacts/2 performs partial and case-insensitive search" do
    contacts = sample_contacts()

    assert [%{"id" => 1}] = Contacts.search_contacts(contacts, {:name, "ana"})
    assert [%{"id" => 2}] = Contacts.search_contacts(contacts, {:phone, "9988"})
    assert [%{"id" => 1}] = Contacts.search_contacts(contacts, {:email, "ACME.COM"})
  end

  test "edit_contact/3 updates only informed fields" do
    contacts = sample_contacts()

    updated_contacts =
      Contacts.edit_contact(contacts, 1, %{
        company: "Nova Acme",
        phone: "85900000000"
      })

    assert %{
             "id" => 1,
             "name" => "Ana Lima",
             "company" => "Nova Acme",
             "phone" => "85900000000",
             "email" => "ana.lima@acme.com"
           } = Contacts.get_contact(updated_contacts, 1)
  end

  test "delete_contact/2 removes the contact by id" do
    contacts = sample_contacts()
    remaining_contacts = Contacts.delete_contact(contacts, 1)

    assert Contacts.get_contact(remaining_contacts, 1) == nil
    assert length(remaining_contacts) == 1
  end

  test "validate_new_contact/1 returns friendly errors for empty and invalid fields" do
    assert {:error, errors} =
             Contacts.validate_new_contact(%{
               name: "   ",
               company: "",
               phone: "85abc",
               email: "ana.acme.com"
             })

    assert "Nome nao pode ficar vazio." in errors
    assert "Empresa nao pode ficar vazio." in errors
    assert "Telefone deve conter apenas numeros." in errors
    assert "Telefone deve ter pelo menos 10 digitos." in errors
    assert "Email deve conter @." in errors
  end

  test "validate_contact_updates/1 validates only informed fields" do
    assert {:error, errors} =
             Contacts.validate_contact_updates(%{
               phone: "123",
               email: "bruno.beta.com"
             })

    assert "Telefone deve ter pelo menos 10 digitos." in errors
    assert "Email deve conter @." in errors
  end

  defp sample_contacts do
    [
      %{
        "id" => 1,
        "name" => "Ana Lima",
        "company" => "Acme Ltda",
        "phone" => "85912345678",
        "email" => "ana.lima@acme.com"
      },
      %{
        "id" => 2,
        "name" => "Bruno Costa",
        "company" => "Beta SA",
        "phone" => "85999887766",
        "email" => "bruno@beta.com"
      }
    ]
  end
end

defmodule AgendaCli.ParserTest do
  use ExUnit.Case

  test "parse_add/1 parses multi-word flags into a map" do
    assert {:add,
            %{
              name: "Ana Lima",
              company: "Acme Ltda",
              phone: "85912345678",
              email: "ana@acme.com"
            }} =
             AgendaCli.parse_add([
               "--name",
               "Ana",
               "Lima",
               "--company",
               "Acme",
               "Ltda",
               "--phone",
               "85912345678",
               "--email",
               "ana@acme.com"
             ])
  end

  test "parse_edit/1 parses id and only informed fields" do
    assert {:edit, 123, %{phone: "85999999999"}} =
             AgendaCli.parse_edit(["123", "--phone", "85999999999"])
  end

  test "parse_search/1 parses a single search filter" do
    assert {:search, {:name, "ana"}} =
             AgendaCli.parse_search(["--name", "ana"])
  end

  test "parse_command/1 supports show, del, list and exit" do
    assert {:show, 123} == AgendaCli.parse_command("show 123")
    assert {:del, 456} == AgendaCli.parse_command("del 456")
    assert :list == AgendaCli.parse_command("list")
    assert :exit == AgendaCli.parse_command("exit")
  end

  test "parse_command/1 returns errors for unknown and invalid commands" do
    assert {:error, :unknown_command} == AgendaCli.parse_command("ping")
    assert {:error, :invalid_command} == AgendaCli.parse_command("edit abc --phone 123")
    assert {:error, :invalid_command} == AgendaCli.parse_command("search --company Acme")
  end
end

defmodule AgendaCli.ExecutionTest do
  use ExUnit.Case

  alias AgendaCli.Contacts

  test "main state starts from persisted contacts data" do
    tmp_dir =
      Path.join(
        System.tmp_dir!(),
        "agenda_cli_execution_test_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(tmp_dir)

    on_exit(fn ->
      File.rm_rf!(tmp_dir)
    end)

    contacts = sample_contacts()

    File.cd!(tmp_dir, fn ->
      File.write!("contacts.json", Jason.encode!(contacts))
      assert Contacts.list_contacts(AgendaCli.Store.load()) == contacts
    end)
  end

  test "execute_command/2 lists contacts in table format" do
    state = %{contacts: sample_contacts()}

    assert {:continue, ^state, [output], :noop} = AgendaCli.execute_command(:list, state)
    assert output =~ "id | nome | empresa | telefone | email"
    assert output =~ "1 | Ana Lima | Acme Ltda | 85912345678 | ana.lima@acme.com"
  end

  test "execute_command/2 shows one contact formatted" do
    state = %{contacts: sample_contacts()}

    assert {:continue, ^state, [output], :noop} = AgendaCli.execute_command({:show, 2}, state)
    assert output =~ "id: 2"
    assert output =~ "nome: Bruno Costa"
    assert output =~ "empresa: Beta SA"
  end

  test "execute_command/2 searches contacts using the contacts module" do
    state = %{contacts: sample_contacts()}

    assert {:continue, ^state, [output], :noop} =
             AgendaCli.execute_command({:search, {:email, "ACME"}}, state)

    assert output =~ "Ana Lima"
    refute output =~ "Bruno Costa"
  end

  test "execute_command/2 adds a contact and marks state to save" do
    state = %{contacts: []}

    assert {:continue, new_state, ["Contato adicionado com sucesso."], :save} =
             AgendaCli.execute_command(
               {:add,
                %{
                  name: "Ana Lima",
                  company: "Acme Ltda",
                  phone: "85912345678",
                  email: "ana.lima@acme.com"
                }},
               state
             )

    assert length(new_state.contacts) == 1
    assert [%{"name" => "Ana Lima"}] = new_state.contacts
  end

  test "execute_command/2 rejects invalid contact creation with friendly messages" do
    state = %{contacts: []}

    assert {:continue, ^state, messages, :noop} =
             AgendaCli.execute_command(
               {:add,
                %{
                  name: "Ana Lima",
                  company: "",
                  phone: "85abc",
                  email: "ana.limaacme.com"
                }},
               state
             )

    assert "Empresa nao pode ficar vazio." in messages
    assert "Telefone deve conter apenas numeros." in messages
    assert "Email deve conter @." in messages
  end

  test "execute_command/2 edits only the requested contact and marks state to save" do
    state = %{contacts: sample_contacts()}

    assert {:continue, new_state, ["Contato atualizado com sucesso."], :save} =
             AgendaCli.execute_command({:edit, 1, %{phone: "85900000000"}}, state)

    assert Contacts.get_contact(new_state.contacts, 1)["phone"] == "85900000000"
    assert Contacts.get_contact(new_state.contacts, 2)["phone"] == "85999887766"
  end

  test "execute_command/2 rejects invalid contact updates with friendly messages" do
    state = %{contacts: sample_contacts()}

    assert {:continue, ^state, messages, :noop} =
             AgendaCli.execute_command(
               {:edit, 1, %{phone: "abc", email: "ana.limaacme.com"}},
               state
             )

    assert "Telefone deve conter apenas numeros." in messages
    assert "Telefone deve ter pelo menos 10 digitos." in messages
    assert "Email deve conter @." in messages
  end

  test "execute_command/2 deletes a contact and marks state to save" do
    state = %{contacts: sample_contacts()}

    assert {:continue, new_state, ["Contato removido com sucesso."], :save} =
             AgendaCli.execute_command({:del, 1}, state)

    assert Contacts.get_contact(new_state.contacts, 1) == nil
    assert length(new_state.contacts) == 1
  end

  test "execute_command/2 reports when a contact is not found" do
    state = %{contacts: sample_contacts()}

    assert {:continue, ^state, ["Contato nao encontrado."], :noop} =
             AgendaCli.execute_command({:show, 999}, state)

    assert {:continue, ^state, ["Contato nao encontrado."], :noop} =
             AgendaCli.execute_command({:edit, 999, %{phone: "1"}}, state)

    assert {:continue, ^state, ["Contato nao encontrado."], :noop} =
             AgendaCli.execute_command({:del, 999}, state)
  end

  defp sample_contacts do
    [
      %{
        "id" => 1,
        "name" => "Ana Lima",
        "company" => "Acme Ltda",
        "phone" => "85912345678",
        "email" => "ana.lima@acme.com"
      },
      %{
        "id" => 2,
        "name" => "Bruno Costa",
        "company" => "Beta SA",
        "phone" => "85999887766",
        "email" => "bruno@beta.com"
      }
    ]
  end
end
