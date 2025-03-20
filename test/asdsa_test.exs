defmodule AsdsaTest do
  use ExUnit.Case
  use Params

  @moduletag :asd

  defparams(item_group_embed_params, %{
    item_id!: :integer,
    amount!: [field: :integer, default: 1],
    probability!: [field: :decimal, default: 1.0]
  })

  defparams(_params, %{
    user_id: :binary_id,
    name: :string,
    notes: :string,
    source_items: [
      %{
        item_id!: :integer,
        amount!: [field: :integer, default: 1],
        probability!: [field: :decimal, default: 1.0]
      }
    ],
    target_items: [
      %{
        item_id!: :integer,
        amount!: [field: :integer, default: 1],
        probability!: [field: :decimal, default: 1.0]
      }
    ]
  })

  test "returns map on nested schemas with default values" do
    _params(%{source_items: [%{item_id: 1}]}) |> dbg

    # item_group_embed_params(%{items: [%{item_id: 1}]}) |> dbg
  end
end
