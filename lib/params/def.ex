defmodule Params.Def do
  @moduledoc false
  alias Params.Schema.Field

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

    cast_func = Code.eval_quoted(def_cast_func(full, func_name), [], __CALLER__)

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

    cast_func = Code.eval_quoted(def_cast_func(full, func_name), [], __CALLER__)

    [defmod, with_alias, cast_func]
  end

  @doc false
  defmacro defschema(schema) do
    quote location: :keep, bind_quoted: [schema: schema] do
      normalized_schema = Params.Def.normalize_schema(schema, __MODULE__)
      Code.eval_quoted(Params.Def.gen_root_schema(normalized_schema), [], __ENV__)

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
    inline? = Keyword.get(schema, :inline, false)

    acc =
      if inline? do
        sub_schema = Keyword.get(schema, :fields)
        submodule = Keyword.get(schema, :field) |> elem(1)

        module_def = {submodule, Params.Def.gen_root_schema(sub_schema)}
        new_acc = [module_def | acc]
        build_nested_schemas(sub_schema, new_acc)
      else
        acc
      end

    build_nested_schemas(rest, acc)
  end

  def gen_root_schema(schema) do
    quote location: :keep do
      use Params.Schema

      @schema unquote(Macro.escape(schema))
      {required, optional} = unquote(schema |> Enum.split_with(& &1[:required]))
      @required Enum.map(required, & &1[:name])
      @optional Enum.map(optional, & &1[:name])

      schema do
        (unquote_splicing(schema_fields(schema)))
      end
    end
  end

  defp schema_fields(schema) do
    Enum.map(schema, &schema_field/1)
  end

  defp schema_field(field) do
    {call, type} =
      case field[:field] do
        {:embeds_one, mod} -> {:embeds_one, mod}
        {:embeds_many, mod} -> {:embeds_many, mod}
        type -> {:field, type}
      end

    name = field[:name]
    opts = field[:opts] || []

    quote location: :keep do
      unquote(call)(unquote(name), unquote(type), unquote(opts))
    end
  end

  def normalize_schema(dict, module) do
    Enum.reduce(dict, [], fn {k, v}, list ->
      [Field.new(v, k, module) | list]
    end)
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
