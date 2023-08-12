defmodule Params.Schema.Field do
  def new(field_schema, name, module) do
    name
    |> parse_name()
    |> Map.put(:module, module)
    |> put_field(field_schema)
    |> Keyword.new()
  end

  defp parse_name(name) do
    {required, name} =
      name
      |> to_string()
      |> String.split("!")
      |> case do
        [name] -> {false, name}
        [name, _] -> {true, name}
      end

    %{name: String.to_atom(name), required: required}
  end

  defp put_field(field, {:embeds_one, embed_module}) do
    Map.put(field, :field, {:embeds_one, embed_module})
  end

  defp put_field(field, {:embeds_many, _} = embed) do
    Map.put(field, :field, embed)
  end

  defp put_field(field, %{} = schema) do
    module = module_concat(field.module, field.name)

    Map.merge(field, %{
      field: {:embeds_one, module},
      fields: Params.Def.normalize_schema(schema, module),
      inline: true
    })
  end

  defp put_field(field, [%{} = schema]) do
    module = module_concat(field.module, field.name)

    Map.merge(field, %{
      field: {:embeds_many, module},
      fields: Params.Def.normalize_schema(schema, module),
      inline: true
    })
  end

  defp put_field(field, [{:field, schema} | opts]) do
    field
    |> put_field(schema)
    |> Map.put(:opts, opts)
  end

  defp put_field(field, [primitive]) do
    Map.put(field, :field, {:array, primitive})
  end

  defp put_field(field, {:array, primitive}) do
    Map.put(field, :field, {:array, primitive})
  end

  defp put_field(field, type) when is_atom(type) do
    Map.put(field, :field, type)
  end

  defp module_concat(parent, name) do
    Module.concat([parent, Macro.camelize("#{name}")])
  end
end
