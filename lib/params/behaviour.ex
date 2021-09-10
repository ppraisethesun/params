defmodule Params.Behaviour do
  @moduledoc false

  @type opt ::
          {:struct, boolean}
          | {:with, (Ecto.Changeset.t(), map -> Ecto.Changeset.t())}
  @type opts :: [opt]

  @callback cast(map, opts) :: {:ok, struct | map} | {:error, Ecto.Changeset.t()}
  @callback changeset(Ecto.Changeset.t(), map) :: Ecto.Changeset.t()
end
