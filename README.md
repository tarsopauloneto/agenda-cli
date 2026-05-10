# Agenda CLI

## Descrição

Agenda CLI é uma aplicação de linha de comando feita em Elixir para cadastro e consulta de contatos.
O projeto permite adicionar, listar, buscar, editar, remover e visualizar contatos, com persistência em arquivo JSON.

## Objetivo Acadêmico

Este projeto foi desenvolvido com foco acadêmico para praticar conceitos fundamentais de Elixir e programação funcional, como:

- organização em módulos
- uso de funções puras
- recursão de cauda
- pattern matching
- manipulação de listas com Enum
- persistência simples em JSON

## Tecnologias Utilizadas

- Elixir
- Mix
- JSON

## Estrutura dos Módulos

### `AgendaCli`

Responsável pela interface de linha de comando.

- inicia a aplicação
- executa o loop interativo
- faz o parsing dos comandos
- integra regras de negócio e persistência
- exibe mensagens no terminal

### `AgendaCli.Contacts`

Responsável pela lógica funcional dos contatos.

- adiciona contatos
- edita contatos
- remove contatos
- busca contatos
- valida dados

### `AgendaCli.Store`

Responsável pela persistência em JSON.

- carrega os contatos do arquivo `contacts.json`
- salva os contatos no arquivo `contacts.json`

## Como Instalar as Dependências

No diretório do projeto, execute:

```bash
mix deps.get
```

## Como Executar

Para baixar as dependências:

```bash
mix deps.get
```

Para iniciar a aplicação:

```bash
mix run
```

Ao iniciar, o prompt será exibido assim:

```text
agenda>
```

Para encerrar:

```text
exit
```

## Exemplos de Comandos

### Adicionar contato

```text
add --name Ana Lima --company Acme Ltda --phone 85912345678 --email ana.lima@acme.com
```

### Listar contatos

```text
list
```

### Mostrar um contato pelo id

```text
show 1713531600000
```

### Editar um contato

```text
edit 1713531600000 --phone 85999999999
```

Também é possível alterar mais de um campo:

```text
edit 1713531600000 --company Nova Acme --email ana@novaacme.com
```

### Remover um contato

```text
del 1713531600000
```

### Buscar contatos

Busca por nome:

```text
search --name ana
```

Busca por telefone:

```text
search --phone 8591
```

Busca por email:

```text
search --email acme.com
```

## Persistência em JSON

Os contatos são armazenados no arquivo `contacts.json`, criado no diretório do projeto.

O salvamento acontece automaticamente após:

- `add`
- `edit`
- `del`

Se o arquivo não existir, a aplicação começa com uma lista vazia.
Se o conteúdo do JSON estiver inválido, a aplicação também considera lista vazia para continuar funcionando de forma simples.

Exemplo de estrutura do arquivo:

```json
[
  {
    "id": 1713531600000,
    "name": "Ana Lima",
    "company": "Acme Ltda",
    "phone": "85912345678",
    "email": "ana.lima@acme.com"
  }
]
```

## Programação Funcional no Projeto

O projeto segue uma abordagem funcional e simples:

- o estado da aplicação é mantido por recursão de cauda no loop principal
- não há variáveis globais
- as funções retornam novos valores em vez de alterar estruturas existentes
- o parsing dos comandos foi separado da lógica de negócio
- a manipulação dos contatos foi isolada em um módulo específico

Essa organização ajuda a deixar o código mais previsível, legível e fácil de testar.
