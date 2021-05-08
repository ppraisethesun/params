defmodule Params.SchemaTest do
  use ExUnit.Case
  import Ecto.Changeset

  alias Ecto.Changeset

  defmodule PetParams do
    use Params.Schema

    schema do
      field(:name)
      field(:age, :integer)
    end
  end

  test "module has schema types" do
    assert %{age: :integer, name: :string, _id: :binary_id} ==
             PetParams.__changeset__()
  end

  test "defaults to no required fields" do
    assert [] == Params.required(PetParams)
  end

  test "defaults to all optional fields" do
    assert [:_id, :age, :name] == Params.optional(PetParams)
  end

  test "from returns a changeset" do
    ch = PetParams.from(%{})
    assert %Changeset{} = ch
  end

  test "fields are castable" do
    ch = PetParams.from(%{"age" => "2"})
    assert 2 = Changeset.get_change(ch, :age)
  end

  defmodule LocationParams do
    use Params.Schema
    @required ~w(latitude longitude)
    schema do
      field(:latitude, :float)
      field(:longitude, :float)
    end
  end

  defmodule BusParams do
    use Params.Schema
    @required ~w(origin destination)
    schema do
      embeds_one(:origin, LocationParams)
      embeds_one(:destination, LocationParams)
    end
  end

  test "invalid changeset on missing params" do
    assert %{valid?: false} = BusParams.from(%{})
  end

  test "only valid if nested required present" do
    params = %{
      "origin" => %{
        "latitude" => 12.2,
        "longitude" => 13.3
      },
      "destination" => %{
        "latitude" => 12.2,
        "longitude" => 13.3
      }
    }

    assert %{valid?: true} = BusParams.from(params)
  end

  test "invalid if nested required missing" do
    params = %{
      "origin" => %{
        "latitude" => 12.2
      },
      "destination" => %{
        "longitude" => 13.3
      }
    }

    assert %{valid?: false} = changeset = BusParams.from(params)
    assert {:error, %{valid?: false}} = Params.to_map(changeset)
  end

  test "to_map gets map of struct except for _id" do
    params = %{
      "latitude" => 12.2,
      "longitude" => 13.3
    }

    assert {:ok, result} =
             params
             |> LocationParams.from()
             |> Params.to_map()

    assert result == %{latitude: 12.2, longitude: 13.3}
  end

  defmodule DefaultNested do
    use Params.Schema, %{
      a: :string,
      b: :string,
      c: [field: :string, default: "C"],
      d: %{
        e: :string,
        f: :string,
        g: [field: :string, default: "G"]
      },
      h: %{
        i: :string,
        j: :string,
        k: [field: :string, default: "K"]
      },
      l: %{
        m: :string
      },
      n: %{
        o: %{
          p: [field: :string, default: "P"]
        }
      }
    }
  end

  test "to_map only returns submitted fields" do
    assert {:ok, result} =
             %{
               a: "A",
               d: %{
                 e: "E",
                 g: "g"
               }
             }
             |> DefaultNested.from()
             |> Params.to_map()

    assert result == %{
             a: "A",
             c: "C",
             d: %{e: "E", g: "g"},
             h: %{k: "K"},
             n: %{
               o: %{p: "P"}
             }
           }
  end

  defmodule DefaultCountParams do
    use Params.Schema

    schema do
      field(:count, :integer, default: 1)
    end
  end

  test "use Params.Schema respects defaults" do
    changeset = DefaultCountParams.from(%{})
    assert {:ok, %{count: 1}} = Params.to_map(changeset)
  end
end
