# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.BbParameterStoreCubdb.Install do
    @shortdoc "Installs BB.Parameter.Store.CubDB into a robot"
    @moduledoc """
    #{@shortdoc}

    Adds `BB.Parameter.Store.CubDB.Dsl` to the robot's `use BB` and declares a
    `parameter_store_cubdb` section, so the robot's parameters survive a reboot.

    The data directory defaults to a path under `/root` — the Nerves application
    data partition — for a project that depends on `:nerves`, and to a path
    under the project's build directory otherwise.

    ## Example

    ```bash
    mix igniter.install bb_parameter_store_cubdb
    mix igniter.install bb_parameter_store_cubdb --robot MyRobot.Robot
    ```
    """

    use Igniter.Mix.Task

    alias Igniter.Code.Common
    alias Igniter.Project.Application, as: ProjectApplication
    alias Igniter.Project.Deps
    alias Igniter.Project.Formatter

    @extension BB.Parameter.Store.CubDB.Dsl

    @impl Igniter.Mix.Task
    def info(_argv, _parent) do
      %Igniter.Mix.Task.Info{
        schema: [robot: :string],
        aliases: [r: :robot]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      robot_module = BB.Igniter.robot_module(igniter)

      igniter
      |> Formatter.import_dep(:bb_parameter_store_cubdb)
      |> Spark.Igniter.add_extension(robot_module, BB, :extensions, @extension)
      |> add_section(robot_module)
    end

    defp add_section(igniter, robot_module) do
      case Spark.Igniter.get_option(igniter, robot_module, [:parameter_store_cubdb, :data_dir]) do
        {igniter, {:ok, _existing}} ->
          igniter

        {igniter, :error} ->
          data_dir = data_dir(igniter)

          Spark.Igniter.update_dsl(
            igniter,
            robot_module,
            [{:section, :parameter_store_cubdb}],
            nil,
            fn zipper -> {:ok, Common.add_code(zipper, ~s|data_dir "#{data_dir}"|)} end
          )
      end
    end

    defp data_dir(igniter) do
      app_name = ProjectApplication.app_name(igniter)

      if Deps.has_dep?(igniter, :nerves) do
        "/root/#{app_name}_params"
      else
        "_build/#{app_name}_params"
      end
    end
  end
else
  defmodule Mix.Tasks.BbParameterStoreCubdb.Install do
    @shortdoc "Installs BB.Parameter.Store.CubDB into a robot"
    @moduledoc false
    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The bb_parameter_store_cubdb.install task requires igniter. Please install igniter and try again.

          mix igniter.install bb_parameter_store_cubdb
      """)

      exit({:shutdown, 1})
    end
  end
end
