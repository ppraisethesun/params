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
    quote location: :keep do
      import Params.Schema, only: [schema: 1]
      unquote(__use__(:ecto))
      unquote(__use__(:params))
    end
  end

  defmacro __using__(schema) do
    quote location: :keep, bind_quoted: [schema: schema] do
      import Params.Def

      defschema(schema)
    end
  end

  @doc false
  defmacro schema(do: definition) do
    quote location: :keep do
      Ecto.Schema.embedded_schema do
        unquote(definition)
      end
    end
  end

  defp __use__(:ecto) do
    quote location: :keep do
      use Ecto.Schema
      import Ecto.Changeset
      @primary_key false
    end
  end

  defp __use__(:params) do
    quote location: :keep do
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
        do_output = &Params.Schema.output(&1, Keyword.get(opts, :struct, false))

        __MODULE__
        |> struct()
        |> Ecto.Changeset.change()
        |> on_cast.(params)
        |> do_output.()
      end

      @impl true
      def changeset(cs, params) do
        Params.Schema.changeset(cs, params)
      end

      defoverridable changeset: 2
    end
  end

  alias Ecto.Changeset

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

  def output(%Changeset{valid?: true} = cs, struct?), do: {:ok, do_output(cs, struct?)}
  def output(cs, _), do: {:error, cs}

  defp do_output(%Changeset{data: data, valid?: true} = cs, struct?) do
    default_embeds = default_embeds_from_schema(data.__struct__, cs.params, struct?)

    default =
      case default_embeds do
        %_{} -> Map.from_struct(default_embeds)
        map -> map
      end
      |> Enum.reduce(data, fn {field, default_value}, acc ->
        Map.update!(acc, field, fn
          nil -> default_value
          [] when default_value == :none -> nil
          value -> value
        end)
      end)

    explicit_nils =
      cs.data
      |> Map.from_struct()
      |> Enum.reduce(%{}, fn {field, _}, acc ->
        case Map.fetch(cs.params, "#{field}") do
          {:ok, nil} -> Map.put(acc, field, nil)
          _ -> acc
        end
      end)

    struct =
      Enum.reduce(cs.changes, Map.merge(default, explicit_nils), fn {field, value}, acc ->
        value
        |> case do
          %Changeset{} -> Map.put(acc, field, do_output(value, struct?))
          x = [%Changeset{} | _] -> Map.put(acc, field, Enum.map(x, &do_output(&1, struct?)))
          _ -> Map.put(acc, field, value)
        end
      end)

    if struct? do
      struct
    else
      to_map(struct, cs.params)
    end
  end

  @doc false
  defp default_embeds_from_schema(module, changeset_params, struct?) when is_atom(module) do
    is_embed = fn field ->
      Enum.any?(Keyword.get(field, :fields, []), fn field ->
        Keyword.has_key?(field[:opts] || [], :default)
      end)
    end

    default_embed = fn field ->
      name = Keyword.get(field, :name)

      default =
        case field[:field] do
          {:embeds_one, mod} ->
            embed_params = Map.get(changeset_params, "#{name}", %{})
            default_embeds_from_schema(mod, embed_params, struct?)

          {:embeds_many, mod} ->
            case Map.get(changeset_params, "#{name}", :none) do
              list when is_list(list) ->
                Enum.map(list, &default_embeds_from_schema(mod, &1, struct?))

              other ->
                other
            end
        end

      {name, default}
    end

    struct =
      struct(
        module,
        case __schema__(module) do
          # non-params struct
          nil -> %{}
          schema -> schema |> Enum.filter(is_embed) |> Map.new(default_embed)
        end
      )

    if struct? do
      struct
    else
      to_map(struct, changeset_params)
    end
  end

  # transform struct into map removing all non-explicit nils
  defp to_map(struct, changeset_params) do
    explicit_nils =
      struct
      |> Map.from_struct()
      |> Enum.reduce(%{}, fn {field, _}, acc ->
        case Map.fetch(changeset_params, "#{field}") do
          {:ok, nil} -> Map.put(acc, field, nil)
          _ -> acc
        end
      end)

    struct
    |> Map.from_struct()
    |> Map.filter(fn
      {k, nil} -> Map.has_key?(explicit_nils, k)
      _ -> true
    end)
  end

  @doc false
  def changeset(%Changeset{data: %{__struct__: module}} = cs, params) do
    {required, required_relations} = relation_partition(module, __required__(module))
    {optional, optional_relations} = relation_partition(module, __optional__(module))

    cs
    |> Changeset.cast(params, required ++ optional, empty_values: [])
    |> Changeset.validate_required(required)
    |> cast_relations(required_relations, required: true)
    |> cast_relations(optional_relations, [])
  end

  @doc false
  def changeset(%{__struct__: _} = model, params) do
    model
    |> Changeset.change()
    |> changeset(params)
  end

  @relations [:embed, :assoc]
  defp relation_partition(module, names) do
    types = module.__changeset__()

    Enum.reduce(names, {[], []}, fn name, {fields, relations} ->
      case Map.get(types, name) do
        {type, _} when type in @relations ->
          {fields, [{name, type} | relations]}

        _ ->
          {[name | fields], relations}
      end
    end)
  end

  defp cast_relations(cs, relations, opts) do
    Enum.reduce(relations, cs, fn
      {name, :assoc}, ch -> Changeset.cast_assoc(ch, name, opts)
      {name, :embed}, ch -> Changeset.cast_embed(ch, name, opts)
    end)
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
