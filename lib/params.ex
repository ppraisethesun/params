defmodule Params do
  @moduledoc ~S"""
  `use Params` provides a `defparams` macro, allowing you to define
  functions that process parameters according to some [schema](Params.Schema.html)

  ## Example

  ```elixir
    defparams login_params, %{
      email!: :string,
      password!: :string
    }

    ...> login_params(%{email: "email", password: "password"})
    {:ok, %{email: "email", password: "password"}}
    ...> login_params(%{})
    {:error, %Ecto.Changeset{}}

    ...> login_params(%{email: "email", password: "password"}, struct: true)
    {:ok, %LoginParams{email: "email", password: "password"}}
  ```

  You can also add additional validation in a do: block by overriding changeset/2 function
  ```elixir
    defparams kid, %{name: :string, age: :integer} do
      @impl true
      def changeset(ch, params) do
        cast(ch, params, ~w(name age)a)
        |> validate_inclusion(:age, 1..6)
      end
    end

    ...> kid(%{name: "hugo", age: 10})
    {:error, %{valid?: false, errors: [age: _]}}

    ...> kid(%{name: "hugo", age: 5})
    {:ok, %{name: "hugo", age: 5}}

    ...> kid(%{name: "hugo", age: nil})
    {:ok, %{name: "hugo", age: nil}}

    ...> kid(%{name: "hugo"})
    {:ok, %{name: "hugo"}}
  ```
  """

  @doc false
  defmacro __using__([]) do
    quote location: :keep do
      import Params.Def, only: [defparams: 2, defparams: 3, defschema: 1]
    end
  end
end
