defmodule DefParamsTest do
  use ExUnit.Case
  use Params
  import Ecto.Changeset

  alias Ecto.Changeset

  describe "defparams name, schema. nested" do
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
      assert [:near_location, :breed] = Params.Schema.__required__(DefParamsTest.Kitten)
    end

    test "kitten module has list of optional fields" do
      assert [:age_min, :age_max] = Params.Schema.__optional__(DefParamsTest.Kitten)
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

    test "returns fields explicitly set to nil" do
      params = %{
        "breed" => "Russian Blue",
        "age_min" => nil,
        "near_location" => %{
          "latitude" => nil,
          "longitude" => "-90.0"
        }
      }

      assert {:ok, %{age_min: nil, near_location: %{latitude: nil}} = map} = kitten(params)
      refute Map.has_key?(map, :age_max)

      params = %{
        breed: "Russian Blue",
        age_min: nil,
        near_location: %{
          latitude: nil,
          longitude: "-90.0"
        }
      }

      assert {:ok, %{age_min: nil, near_location: %{latitude: nil}} = map} = kitten(params)
      refute Map.has_key?(map, :age_max)
    end

    test "returns struct when params are valid" do
      params = %{
        "breed" => "Russian Blue",
        "age_min" => "0",
        "age_max" => "4",
        "near_location" => %{
          "latitude" => "87.5",
          "longitude" => "-90.0"
        }
      }

      assert {:ok, %DefParamsTest.Kitten{}} = kitten(params, struct: true)
    end
  end

  describe "defparams name, schema. embeds" do
    defparams(location_params, %{
      latitude: :float,
      longitude: :float
    })

    defparams(puppy, %{
      breed!: :string,
      age_min: :integer,
      age_max: :integer,
      near_location!: {:embeds_one, LocationParams}
    })

    test "puppy module has list of required fields" do
      assert [:near_location, :breed] = Params.Schema.__required__(DefParamsTest.Puppy)
    end

    test "puppy module has list of optional fields" do
      assert [:age_min, :age_max] = Params.Schema.__optional__(DefParamsTest.Puppy)
    end

    test "puppy returns error with changeset if params are invalid" do
      assert {:error, %Changeset{}} = puppy(%{})
    end

    test "puppy returns a map when params are valid" do
      params = %{
        "breed" => "Russian Blue",
        "age_min" => "0",
        "age_max" => "4",
        "near_location" => %{
          "latitude" => "87.5",
          "longitude" => "-90.0"
        }
      }

      assert {:ok, %{}} = puppy(params)
    end

    test "returns fields explicitly set to nil within embeds_one" do
      params = %{
        "breed" => "Russian Blue",
        "age_min" => "0",
        "age_max" => "4",
        "near_location" => %{
          "latitude" => nil,
          "longitude" => "-90.0"
        }
      }

      assert {:ok, %{near_location: %{latitude: nil}}} = puppy(params)

      params = %{
        breed: "Russian Blue",
        age_min: "0",
        age_max: "4",
        near_location: %{
          latitude: nil,
          longitude: "-90.0"
        }
      }

      assert {:ok, %{near_location: %{latitude: nil}}} = puppy(params)
    end

    test "puppy returns struct when params are valid" do
      params = %{
        "breed" => "Russian Blue",
        "age_min" => "0",
        "age_max" => "4",
        "near_location" => %{
          "latitude" => "87.5",
          "longitude" => "-90.0"
        }
      }

      assert {:ok, %DefParamsTest.Puppy{}} = puppy(params, struct: true)
    end

    defparams(dragon, %{
      breed!: :string,
      age_min: :integer,
      age_max: :integer,
      near_locations!: {:embeds_many, LocationParams}
    })

    test "dragon module has list of required fields" do
      assert [:near_locations, :breed] = Params.Schema.__required__(DefParamsTest.Dragon)
    end

    test "dragon module has list of optional fields" do
      assert [:age_min, :age_max] = Params.Schema.__optional__(DefParamsTest.Dragon)
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

      assert {:ok, %{}} = dragon(params)
    end

    test "returns fields explicitly set to nil within embeds" do
      params = %{
        "breed" => "Russian Blue",
        "age_min" => "0",
        "age_max" => "4",
        "near_locations" => [
          %{
            "latitude" => nil,
            "longitude" => nil
          },
          %{}
        ]
      }

      assert {:ok, %{near_locations: [%{latitude: nil, longitude: nil}, second_location]}} =
               dragon(params)

      assert second_location == %{}
    end

    test "dragon returns struct when all data is ok" do
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

      assert {:ok, %DefParamsTest.Dragon{}} = dragon(params, struct: true)
    end
  end

  describe "defparams name, schema, do: block." do
    defparams kid, %{name: :string, age: :integer} do
      def custom(ch, params) do
        cast(ch, params, ~w(name age)a)
        |> validate_required([:name])
        |> validate_inclusion(:age, 10..20)
      end

      @impl true
      def changeset(ch, params) do
        cast(ch, params, ~w(name age)a)
        |> validate_inclusion(:age, 1..6)
      end
    end

    test "uses overriden changeset function" do
      assert {:error, %{valid?: false, errors: errors}} = kid(%{name: "hugo", age: 10})

      assert {"is invalid", _} = errors[:age]

      assert {:ok, %{age: 5}} = kid(%{name: "hugo", age: 5})
    end

    test "can specify changeset function via :with option" do
      assert {:ok, %{}} = kid(%{name: "hugo", age: 10}, with: &Kid.custom/2)
    end
  end

  describe "defschema" do
    defmodule SearchUser do
      use Params

      defschema(%{
        name: :string,
        near: %{
          latitude: :float,
          longitude: :float
        }
      })

      @impl true
      def changeset(ch, params) do
        cast(ch, params, ~w(name)a)
        |> validate_required([:name])
        |> cast_embed(:near)
      end
    end

    test "can define a custom module for params schema" do
      assert {:error, %{valid?: false}} = SearchUser.cast(%{near: %{}})
    end

    test "returns map if params are valid" do
      assert {:ok, %{}} = SearchUser.cast(%{name: "asdda"})
    end
  end

  describe "field options" do
    defparams(string_array, %{tags!: [:string]})

    test "can have param with array of strings" do
      assert {:ok, map} = StringArray.cast(%{"tags" => ["hello", "world"]})
      assert ["hello", "world"] = map.tags
    end

    defparams(many_names, %{names!: [%{name!: :string}]})

    test "can have array of embedded schemas" do
      assert {:ok, map} = ManyNames.cast(%{names: [%{name: "Julio"}, %{name: "Cesar"}]})
      assert ["Julio", "Cesar"] = Enum.map(map.names, & &1.name)
    end

    defparams(schema_options, %{
      foo: [field: :string, default: "FOO"]
    })

    test "can specify raw Ecto.Schema options like default using a keyword list" do
      assert {:ok, data} = schema_options(%{})
      assert data.foo == "FOO"
    end

    test "puts default values in map" do
      assert {:ok, map} = schema_options(%{})
      assert map == %{foo: "FOO"}
    end

    test "puts default values in struct" do
      assert {:ok, struct} = schema_options(%{})
      assert %{foo: "FOO"} = struct
    end

    test "nil overrides default value" do
      assert {:ok, struct} = schema_options(%{foo: nil})
      assert %{foo: nil} = struct

      assert {:ok, struct} = schema_options(%{"foo" => nil})
      assert %{foo: nil} = struct
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

    @default 1
    defparams(context, %{
      attribute!: [
        field: :integer,
        default: @default
      ]
    })

    test "has access to context" do
      assert {:ok, map} = context(%{})
      assert map.attribute == 1
    end

    defparams context_with_block, %{
      attribute!: [
        field: :integer,
        default: @default
      ]
    } do
      nil
    end

    test "has access to context with block" do
      assert {:ok, map} = context_with_block(%{})
      assert map.attribute == 1
    end
  end
end
