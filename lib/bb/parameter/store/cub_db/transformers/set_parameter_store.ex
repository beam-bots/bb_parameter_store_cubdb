# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.Parameter.Store.CubDB.Transformers.SetParameterStore do
  @moduledoc """
  Sets the robot's `parameter_store` setting from the `parameter_store_cubdb`
  section.

  This is what lets the section be the only place a CubDB-backed robot is
  configured, rather than having to repeat the store module under `settings`.

  The checks here are a transformer rather than a verifier because Spark
  reports verifier errors with `IO.warn`, and a robot whose parameters silently
  aren't persisted is exactly what this extension exists to prevent.
  """

  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer
  alias Spark.Error.DslError

  @store BB.Parameter.Store.CubDB
  @cubdb_options [:auto_compact, :auto_file_sync, :data_dir]

  @impl true
  def transform(dsl_state) do
    case {declared?(dsl_state), Transformer.get_option(dsl_state, [:settings], :parameter_store)} do
      {true, nil} -> {:ok, set_parameter_store(dsl_state)}
      {true, existing} -> {:error, conflict_error(dsl_state, existing)}
      {false, _} -> {:error, missing_section_error(dsl_state)}
    end
  end

  defp declared?(dsl_state) do
    not is_nil(Transformer.get_option(dsl_state, [:parameter_store_cubdb], :data_dir))
  end

  defp set_parameter_store(dsl_state) do
    options =
      Enum.map(@cubdb_options, fn option ->
        {option, Transformer.get_option(dsl_state, [:parameter_store_cubdb], option)}
      end)

    Transformer.set_option(dsl_state, [:settings], :parameter_store, {@store, options})
  end

  defp missing_section_error(dsl_state) do
    DslError.exception(
      module: Transformer.get_persisted(dsl_state, :module),
      path: [:parameter_store_cubdb],
      message: """
      This robot includes `BB.Parameter.Store.CubDB.Dsl` but doesn't declare a
      `parameter_store_cubdb` section, so its parameters would not be persisted.

      Declare the section:

          parameter_store_cubdb do
            data_dir "/root/my_robot_params"
          end

      Or remove the extension from `use BB`.
      """
    )
  end

  defp conflict_error(dsl_state, existing) do
    DslError.exception(
      module: Transformer.get_persisted(dsl_state, :module),
      path: [:settings, :parameter_store],
      message: """
      This robot declares a `parameter_store_cubdb` section and also sets
      `parameter_store` to #{inspect(existing)}.

      A robot has one parameter store. Either remove the `parameter_store`
      setting and configure CubDB through the section, or drop the section and
      configure the store directly.
      """
    )
  end
end
