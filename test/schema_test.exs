defmodule Params.SchemaTest do
  use ExUnit.Case

  alias Ecto.Changeset

  describe "use without opts" do
    defmodule PetParams do
      use Params.Schema

      schema do
        field(:name)
        field(:age, :integer)
      end
    end

    test "module has schema types" do
      assert %{age: :integer, name: :string} == PetParams.__changeset__()
    end

    test "__required__ defaults to []" do
      assert [] == Params.Schema.__required__(PetParams)
    end

    test "__optional__ defaults to all fields" do
      assert [:age, :name] == Params.Schema.__optional__(PetParams)
    end

    test "cast returns an ok if params are valid" do
      assert {:ok, map} = PetParams.cast(%{name: "name"})
      assert map[:name] == "name"
    end

    test "cast returns an error if params are invalid" do
      assert {:error, %Changeset{valid?: false}} = PetParams.cast(%{name: 1})
    end
  end

  describe "nested validation" do
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
      assert {:error, %Changeset{valid?: false}} = BusParams.cast(%{})

      assert {:error, %Changeset{valid?: false}} =
               BusParams.cast(%{
                 "origin" => %{
                   "latitude" => 12.2,
                   "longitude" => 13.3
                 }
               })

      assert {:error, %Changeset{valid?: false}} =
               BusParams.cast(%{
                 "destination" => %{
                   "latitude" => 12.2,
                   "longitude" => 13.3
                 }
               })
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

      assert {:ok, %{origin: _, destination: _}} = BusParams.cast(params)
    end
  end
end
