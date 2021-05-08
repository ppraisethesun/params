defmodule DefParamsTest do
  use ExUnit.Case
  use Params
  import Ecto.Changeset

  alias Ecto.Changeset

  defparams(kitten, %{
    breed!: :string,
    age_min: :integer,
    age_max: :integer,
    near_location!: %{
      latitude: :float,
      longitude: :float
    }
  })

  test "kitten module has list of required fields" do
    assert [:near_location, :breed] = Params.required(DefParamsTest.Kitten)
  end

  test "kitten module has list of optional fields" do
    assert [:age_min, :age_max] = Params.optional(DefParamsTest.Kitten)
  end

  test "kitten method returns changeset error if data is invalid" do
    assert {:error, %Changeset{valid?: false}} = kitten(%{})
  end

  test "kitten returns valid changeset when all data is ok" do
    params = %{
      "breed" => "Russian Blue",
      "age_min" => "0",
      "age_max" => "4",
      "near_location" => %{
        "latitude" => "87.5",
        "longitude" => "-90.0"
      }
    }

    assert {:ok, _map} = kitten(params)
  end

  defparams(location_params, %{
    latitude!: :float,
    longitude!: :float
  })

  defparams(puppy, %{
    breed!: :string,
    age_min: :integer,
    age_max: :integer,
    near_location!: {:embeds_one, LocationParams}
  })

  test "puppy module has list of required fields" do
    assert [:near_location, :breed] = Params.required(DefParamsTest.Puppy)
  end

  test "puppy module has list of optional fields" do
    assert [:age_min, :age_max] = Params.optional(DefParamsTest.Puppy)
  end

  test "puppy method returns error with changeset" do
    assert {:error, %Changeset{}} = puppy(%{})
  end

  test "puppy returns valid changeset when all data is ok" do
    params = %{
      "breed" => "Russian Blue",
      "age_min" => "0",
      "age_max" => "4",
      "near_location" => %{
        "latitude" => "87.5",
        "longitude" => "-90.0"
      }
    }

    assert {:ok, _map} = puppy(params)
  end

  defparams(dragon, %{
    breed!: :string,
    age_min: :integer,
    age_max: :integer,
    near_locations!: {:embeds_many, LocationParams}
  })

  test "dragon module has list of required fields" do
    assert [:near_locations, :breed] = Params.required(DefParamsTest.Dragon)
  end

  test "dragon module has list of optional fields" do
    assert [:age_min, :age_max] = Params.optional(DefParamsTest.Dragon)
  end

  test "dragon method returns {:error, changeset}" do
    assert {:error, %Ecto.Changeset{}} = dragon(%{})
  end

  test "dragon returns {:ok, map} when all data is ok" do
    params = %{
      "breed" => "Russian Blue",
      "age_min" => "0",
      "age_max" => "4",
      "near_locations" => [
        %{
          "latitude" => "87.5",
          "longitude" => "-90.0"
        },
        %{
          "latitude" => "67.5",
          "longitude" => "-60.0"
        }
      ]
    }

    assert {:ok, _map} = dragon(params)
  end

  defparams kid, %{name: :string, age: :integer} do
    def custom(ch, params) do
      cast(ch, params, ~w(name age)a)
      |> validate_required([:name])
      |> validate_inclusion(:age, 10..20)
    end

    def changeset(ch, params) do
      cast(ch, params, ~w(name age)a)
      |> validate_inclusion(:age, 1..6)
    end
  end

  test "user can populate with custom changeset" do
    assert {:error, %{valid?: false}} =
             kid(%{name: "hugo", age: 5}, with: &DefParamsTest.Kid.custom/2)
  end

  test "user can override changeset" do
    assert {:ok, _map} = kid(%{name: "hugo", age: 5})
  end

  test "can obtain data from changeset" do
    assert {:ok, m} = kid(%{name: "hugo", age: "5"}, struct: true)
    assert "hugo" == m.name
    assert 5 == m.age
    assert nil == m._id
  end

  defmodule SearchUser do
    @schema %{
      name: :string,
      near: %{
        latitude: :float,
        longitude: :float
      }
    }

    use Params.Schema, @schema

    def changeset(ch, params) do
      cast(ch, params, ~w(name)a)
      |> validate_required([:name])
      |> cast_embed(:near)
    end
  end

  test "can define a custom module for params schema" do
    assert %{valid?: false} = SearchUser.from(%{near: %{}})
  end

  defmodule StringArray do
    use Params.Schema, %{tags!: [:string]}
  end

  test "can have param with array of strings" do
    assert %{valid?: true} = ch = StringArray.from(%{"tags" => ["hello", "world"]})
    assert {:ok, data} = Params.data(ch)
    assert ["hello", "world"] = data.tags
  end

  defmodule ManyNames do
    use Params.Schema, %{names!: [%{name!: :string}]}
  end

  test "can have array of embedded schemas" do
    assert %{valid?: true} = ch = ManyNames.from(%{names: [%{name: "Julio"}, %{name: "Cesar"}]})
    assert {:ok, data} = Params.data(ch)
    assert ["Julio", "Cesar"] = data |> Map.get(:names) |> Enum.map(& &1.name)
  end

  defparams(schema_options, %{
    foo: [field: :string, default: "FOO"]
  })

  test "can specify raw Ecto.Schema options like default using a keyword list" do
    assert {:ok, data} = schema_options(%{}, struct: true)
    assert data.foo == "FOO"
  end

  test "puts default values in map" do
    assert {:ok, map} = schema_options(%{})
    assert map == %{foo: "FOO"}
  end

  test "puts default values in struct" do
    assert {:ok, struct} = schema_options(%{}, struct: true)
    assert %{foo: "FOO"} = struct
  end

  defparams(default_nested, %{
    foo: %{
      bar: :string,
      baz: :string
    },
    bat: %{
      man: [field: :string, default: "BATMAN"],
      wo: %{
        man: [field: :string, default: "BATWOMAN"]
      },
      mo: %{vil: :string}
    }
  })

  test "embeds with defaults are not nil" do
    assert {:ok, data} = default_nested(%{}, struct: true)
    assert data.bat.man == "BATMAN"
    assert data.bat.wo.man == "BATWOMAN"
    assert %{mo: nil} = data.bat
    assert nil == data.foo
  end

  test "to_map works on nested schemas with default values and empty input" do
    {:ok, result} = default_nested(%{})

    assert result == %{
             bat: %{
               man: "BATMAN",
               wo: %{
                 man: "BATWOMAN"
               }
             }
           }
  end

  test "returns map on nested schemas with default values" do
    assert {:ok, result} =
             default_nested(%{
               bat: %{
                 man: "Bruce"
               }
             })

    assert result == %{
             bat: %{
               man: "Bruce",
               wo: %{
                 man: "BATWOMAN"
               }
             }
           }
  end
end
