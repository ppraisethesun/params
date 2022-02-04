defmodule Params.Schema do
  @moduledoc ~S"""
  Defines a params schema for a module.

  A params schema is just a map where keys are the parameter name
  (ending with a `!` to mark the parameter as required) and the
  value is either a valid Ecto.Type, another map for embedded schemas
  or an array of those.

  ## Example

  ```elixir
     defmodule ProductSearch do
       use Params.Schema, %{
         text!: :string,
         near: %{
           latitude!:  :float,
           longitude!: :float
         },
         tags: [:string]
       }
     end
  ```

  To cast ProductSearch params use:

  ```elixir
    ...> ProductSearch.cast(params)
     {:ok, map} | {:error, %Ecto.Changeset{}}
  ```
  """

  @doc false
  defmacro __using__([]) do
    quote do
      import Params.Schema, only: [schema: 1]
      unquote(__use__(:ecto))
      unquote(__use__(:params))
    end
  end

  defmacro __using__(schema) do
    quote bind_quoted: [schema: schema] do
      import Params.Def

      defschema(schema)
    end
  end

  @doc false
  defmacro schema(do: definition) do
    quote do
      Ecto.Schema.embedded_schema do
        unquote(definition)
      end
    end
  end

  defp __use__(:ecto) do
    quote do
      use Ecto.Schema
      import Ecto.Changeset
      @primary_key false
    end
  end

  defp __use__(:params) do
    quote do
      Module.register_attribute(__MODULE__, :required, persist: true)
      Module.register_attribute(__MODULE__, :optional, persist: true)
      Module.register_attribute(__MODULE__, :schema, persist: true)

      @behaviour Params.Behaviour

      @default_opts [
        with: &__MODULE__.changeset/2,
        struct: false
      ]
      @impl true
      def cast(params, opts \\ []) when is_list(opts) do
        opts = Keyword.merge(@default_opts, opts)

        on_cast = Keyword.get(opts, :with)

        output =
          case Keyword.get(opts, :struct) do
            true -> &Params.Schema.to_struct/1
            false -> &Params.Schema.to_map/1
          end

        __MODULE__
        |> struct()
        |> Ecto.Changeset.change()
        |> on_cast.(params)
        |> output.()
      end

      @impl true
      def changeset(changeset, params) do
        Params.Schema.changeset(changeset, params)
      end

      defoverridable changeset: 2
    end
  end

  alias Ecto.Changeset

  @relations [:embed, :assoc]

  @doc """
  Transforms an Ecto.Changeset into a struct or a map with atom keys.

  Recursively traverses and transforms embedded changesets

  Skips keys that were not part of params given to changeset if :struct is false
  For example if the `LoginParams` module was defined like:

  ```elixir
  defmodule LoginParams do
     use Params.Schema, %{login!: :string, password!: :string}
  end
  ```

  You can transform the changeset returned by `from` into a map like:
  ```elixir
    ...> {:ok, map} = LoginParams.cast(%{"login" => "foo"})
    map.login # => "foo"
  ```

  or into a struct:

  ```elixir
    ...> {:ok, %LoginParams{} = struct} = LoginParams.cast(%{"login" => "foo"}, struct: true)
    struct.login # => "foo"
  ```
  """

  def to_map(%Changeset{data: %{__struct__: module}, valid?: true} = ch) do
    ecto_defaults = plain_defaults_defined_by_ecto_schema(module)
    params_defaults = module |> __schema__() |> defaults()
    change = changes(ch)

    {:ok,
     ecto_defaults
     |> deep_merge(params_defaults)
     |> deep_merge(change)}
  end

  def to_map(changeset), do: {:error, changeset}

  def to_struct(%Changeset{valid?: true} = changeset) do
    {:ok, extract_data(changeset)}
  end

  def to_struct(changeset), do: {:error, changeset}

  defp extract_data(%Changeset{data: %{__struct__: module} = data, valid?: true} = changeset) do
    default_embeds = default_embeds_from_schema(module)

    default =
      Enum.reduce(default_embeds, data, fn {field, default_value}, acc ->
        Map.update!(acc, field, fn
          nil -> default_value
          value -> value
        end)
      end)

    Enum.reduce(changeset.changes, default, fn {field, value}, acc ->
      case value do
        %Changeset{} -> Map.put(acc, field, extract_data(value))
        x = [%Changeset{} | _] -> Map.put(acc, field, Enum.map(x, &extract_data/1))
        _ -> Map.put(acc, field, value)
      end
    end)
  end

  @doc false
  def default_embeds_from_schema(module) when is_atom(module) do
    is_embed_default = fn kw ->
      kw
      |> Keyword.get(:embeds, [])
      |> Enum.any?(&Keyword.has_key?(&1, :default))
    end

    default_embed = fn kw ->
      name = Keyword.get(kw, :name)
      embed_name = Params.Def.module_concat(module, name)
      {name, default_embeds_from_schema(embed_name)}
    end

    case __schema__(module) do
      nil ->
        %{}

      schema ->
        schema
        |> Enum.filter(is_embed_default)
        |> Enum.map(default_embed)
        |> Enum.into(module |> struct() |> Map.from_struct())
    end
  end

  @doc false
  def changeset(%Changeset{data: %{__struct__: module}} = changeset, params) do
    {required, required_relations} = relation_partition(module, __required__(module))

    {optional, optional_relations} = relation_partition(module, __optional__(module))

    changeset
    |> Changeset.cast(params, required ++ optional)
    |> Changeset.validate_required(required)
    |> cast_relations(required_relations, required: true)
    |> cast_relations(optional_relations, [])
  end

  @doc false
  def changeset(model = %{__struct__: _}, params) do
    model
    |> Changeset.change()
    |> changeset(params)
  end

  defp relation_partition(module, names) do
    types = module.__changeset__

    names
    |> Enum.map(fn x -> String.to_atom("#{x}") end)
    |> Enum.reduce({[], []}, fn name, {fields, relations} ->
      case Map.get(types, name) do
        {type, _} when type in @relations ->
          {fields, [{name, type} | relations]}

        _ ->
          {[name | fields], relations}
      end
    end)
  end

  defp cast_relations(changeset, relations, opts) do
    Enum.reduce(relations, changeset, fn
      {name, :assoc}, ch -> Changeset.cast_assoc(ch, name, opts)
      {name, :embed}, ch -> Changeset.cast_embed(ch, name, opts)
    end)
  end

  defp deep_merge(%{} = map_1, %{} = map_2) do
    Map.merge(map_1, map_2, &deep_merge_conflict/3)
  end

  defp deep_merge_conflict(_k, %{} = m1, %{} = m2) do
    deep_merge(m1, m2)
  end

  defp deep_merge_conflict(_k, _v1, v2), do: v2

  defp defaults(params), do: defaults(params, %{}, [])
  defp defaults(params, acc, path)
  defp defaults([], acc, _path), do: acc
  defp defaults(nil, _acc, _path), do: %{}

  defp defaults([opts | rest], acc, path) when is_list(opts) do
    defaults([Enum.into(opts, %{}) | rest], acc, path)
  end

  defp defaults([%{name: name, embeds: embeds} | rest], acc, path) do
    acc = defaults(embeds, acc, [name | path])
    defaults(rest, acc, path)
  end

  defp defaults([%{name: name, default: value} | rest], acc, path) do
    funs =
      [name | path]
      |> Enum.reverse()
      |> Enum.map(fn nested_name ->
        fn :get_and_update, data, next ->
          with {nil, inner_data} <- next.(data[nested_name] || %{}),
               data = Map.put(data, nested_name, inner_data),
               do: {nil, data}
        end
      end)

    acc = put_in(acc, funs, value)
    defaults(rest, acc, path)
  end

  defp defaults([%{} | rest], acc, path) do
    defaults(rest, acc, path)
  end

  defp changes(%Changeset{} = ch) do
    Enum.reduce(ch.changes, %{}, fn {k, v}, m ->
      case v do
        %Changeset{} -> Map.put(m, k, changes(v))
        x = [%Changeset{} | _] -> Map.put(m, k, Enum.map(x, &changes/1))
        _ -> Map.put(m, k, v)
      end
    end)
  end

  defp plain_defaults_defined_by_ecto_schema(module) do
    module
    |> struct()
    |> Map.from_struct()
    |> Map.delete(:__meta__)
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end

  @doc false
  def __required__(module) when is_atom(module) do
    module.__info__(:attributes) |> Keyword.get(:required, [])
  end

  @doc false
  def __optional__(module) when is_atom(module) do
    module.__info__(:attributes)
    |> Keyword.get(:optional)
    |> case do
      nil -> Map.keys(module.__changeset__())
      x -> x
    end
  end

  @doc false
  def __schema__(module) when is_atom(module) do
    module.__info__(:attributes) |> Keyword.get(:schema)
  end
end
