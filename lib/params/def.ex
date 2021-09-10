defmodule Params.Def do
  @moduledoc false

  @doc false
  defmacro defparams({func_name, _, _}, schema, do: block) do
    block = Macro.escape(block)
    {full, with_alias} = module_name(func_name, __CALLER__)

    defmod =
      quote location: :keep, bind_quoted: [full: full, schema: schema, block: block] do
        defmodule full do
          Params.Def.defschema(schema)
          Code.eval_quoted(block, [], __ENV__)
        end
      end

    cast_func = Module.eval_quoted(__CALLER__.module, def_cast_func(full, func_name))

    [defmod, with_alias, cast_func]
  end

  @doc false
  defmacro defparams({func_name, _, _}, schema) do
    {full, with_alias} = module_name(func_name, __CALLER__)

    defmod =
      quote location: :keep, bind_quoted: [full: full, schema: schema] do
        defmodule full do
          Params.Def.defschema(schema)
        end
      end

    cast_func = Module.eval_quoted(__CALLER__.module, def_cast_func(full, func_name))

    [defmod, with_alias, cast_func]
  end

  @doc false
  defmacro defschema(schema) do
    quote bind_quoted: [schema: schema] do
      normalized_schema = Params.Def.normalize_schema(schema, __MODULE__)
      Module.eval_quoted(__MODULE__, Params.Def.gen_root_schema(normalized_schema))

      normalized_schema
      |> Params.Def.build_nested_schemas()
      |> Enum.each(fn {name, content} ->
        Module.create(name, content, Macro.Env.location(__ENV__))
      end)
    end
  end

  def build_nested_schemas(schemas, acc \\ [])
  def build_nested_schemas([], acc), do: acc

  def build_nested_schemas([schema | rest], acc) do
    embedded = Keyword.has_key?(schema, :embeds)

    acc =
      if embedded do
        sub_schema = Keyword.get(schema, :embeds)

        module_def = {
          sub_schema |> List.first() |> Keyword.get(:module),
          Params.Def.gen_root_schema(sub_schema)
        }

        new_acc = [module_def | acc]
        build_nested_schemas(sub_schema, new_acc)
      else
        acc
      end

    build_nested_schemas(rest, acc)
  end

  def module_concat(parent, name) do
    Module.concat([parent, Macro.camelize("#{name}")])
  end

  def gen_root_schema(schema) do
    quote do
      use Params.Schema

      @schema unquote(schema)
      @required unquote(field_names(schema, &required?/1))
      @optional unquote(field_names(schema, &optional?/1))

      schema do
        (unquote_splicing(schema_fields(schema)))
      end
    end
  end

  defp required?(field_schema), do: Keyword.get(field_schema, :required, false)
  defp optional?(field_schema), do: !required?(field_schema)

  defp field_names(schema, filter) do
    schema
    |> Enum.filter(filter)
    |> Enum.map(&Keyword.get(&1, :name))
  end

  defp schema_fields(schema) do
    Enum.map(schema, &schema_field/1)
  end

  defp schema_field(meta) do
    call = field_call(meta)
    name = Keyword.get(meta, :name)
    type = field_type(meta)
    opts = field_options(meta)

    quote do
      unquote(call)(unquote(name), unquote(type), unquote(opts))
    end
  end

  defp field_call(meta) do
    cond do
      Keyword.get(meta, :field) ->
        :field

      Keyword.get(meta, :embeds_one) ->
        :embeds_one

      Keyword.get(meta, :embeds_many) ->
        :embeds_many

      Keyword.get(meta, :embeds) ->
        "embeds_#{Keyword.get(meta, :cardinality, :one)}" |> String.to_atom()
    end
  end

  defp field_type(meta) do
    module = Keyword.get(meta, :module)
    name = Keyword.get(meta, :name)

    cond do
      Keyword.get(meta, :field) -> Keyword.get(meta, :field)
      Keyword.get(meta, :embeds) -> module_concat(module, name)
      Keyword.get(meta, :embeds_one) -> Keyword.get(meta, :embeds_one)
      Keyword.get(meta, :embeds_many) -> Keyword.get(meta, :embeds_many)
    end
  end

  defp field_options(meta) do
    Keyword.drop(meta, [
      :module,
      :name,
      :field,
      :embeds,
      :embeds_one,
      :embeds_many,
      :required,
      :cardinality
    ])
  end

  def normalize_schema(dict, module) do
    Enum.reduce(dict, [], fn {k, v}, list ->
      [normalize_field({module, k, v}) | list]
    end)
  end

  defp normalize_field({module, k, v}) do
    required = String.ends_with?("#{k}", "!")
    name = String.replace_trailing("#{k}", "!", "") |> String.to_atom()
    normalize_field(v, name: name, required: required, module: module)
  end

  defp normalize_field({:embeds_one, embed_module}, options) do
    [embeds_one: embed_module] ++ options
  end

  defp normalize_field({:embeds_many, embed_module}, options) do
    [embeds_many: embed_module] ++ options
  end

  defp normalize_field(schema = %{}, options) do
    module = module_concat(Keyword.get(options, :module), Keyword.get(options, :name))
    [embeds: normalize_schema(schema, module)] ++ options
  end

  defp normalize_field(value, options) when is_atom(value) do
    [field: value] ++ options
  end

  defp normalize_field({:array, x}, options) do
    normalize_field([x], options)
  end

  defp normalize_field([x], options) when is_map(x) do
    [cardinality: :many] ++ normalize_field(x, options)
  end

  defp normalize_field([{:field, x} | kw], options) do
    normalize_field(x, options) ++ kw
  end

  defp normalize_field([value], options) do
    [field: {:array, value}] ++ options
  end

  defp module_name(func_name, env) do
    alias = Module.concat([Macro.camelize("#{func_name}")])
    full = Module.concat(env.module, alias)

    meta = [defined: full, context: env.module]
    with_alias = {:alias, meta, [full, [as: alias, warn: false]]}

    {full, with_alias}
  end

  def def_cast_func(mod, func_name) do
    quote location: :keep, bind_quoted: [mod: mod, func_name: func_name] do
      def unquote(func_name)(params, opts \\ []) do
        unquote(mod).cast(params, opts)
      end
    end
  end
end
