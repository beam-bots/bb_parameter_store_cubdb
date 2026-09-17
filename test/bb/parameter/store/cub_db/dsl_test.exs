# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.Parameter.Store.CubDB.DslTest do
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias BB.Parameter.Store.CubDB.TestRobots.{ViaAppEnv, ViaExtension, ViaSettings}
  alias Spark.Dsl.Extension
  alias Spark.Error.DslError

  setup do
    File.rm_rf!("tmp")
    on_exit(fn -> File.rm_rf!("tmp") end)
    :ok
  end

  describe "the parameter_store_cubdb section" do
    test "sets the robot's parameter_store setting" do
      assert {BB.Parameter.Store.CubDB, opts} =
               Extension.get_opt(ViaExtension, [:settings], :parameter_store)

      assert opts[:data_dir] == "tmp/via_extension"
    end

    test "passes the section's CubDB options through" do
      {_store, opts} = Extension.get_opt(ViaExtension, [:settings], :parameter_store)

      assert opts[:auto_compact] == true
      assert opts[:auto_file_sync] == true
    end

    test "requires a data directory" do
      assert_raise Spark.Error.DslError, ~r/required :data_dir option not found/, fn ->
        defmodule NoDataDir do
          use BB, extensions: [BB.Parameter.Store.CubDB.Dsl]

          parameter_store_cubdb do
          end

          topology do
            link :base_link
          end
        end
      end
    end
  end

  describe "configuration from the application environment" do
    test "resolves data_dir at compile time" do
      assert {BB.Parameter.Store.CubDB, opts} =
               Extension.get_opt(ViaAppEnv, [:settings], :parameter_store)

      assert opts[:data_dir] == Application.get_env(:bb_parameter_store_cubdb, :params_dir)
    end

    test "persists into the configured directory" do
      start_supervised!(ViaAppEnv)

      assert :ok = BB.Parameter.set(ViaAppEnv, [:kp], 3.5)

      stop_supervised!(ViaAppEnv)
      start_supervised!(ViaAppEnv)

      assert BB.Parameter.get!(ViaAppEnv, [:kp]) == 3.5
      assert File.dir?("tmp/via_app_env")
    end

    test "an unset config key is a compile error rather than a nil path" do
      assert_raise DslError, ~r/data_dir/, fn ->
        defmodule UnsetKey do
          use BB, extensions: [BB.Parameter.Store.CubDB.Dsl]

          parameter_store_cubdb do
            data_dir Application.compile_env(:bb_parameter_store_cubdb, :not_configured)
          end

          topology do
            link :base_link
          end
        end
      end
    end
  end

  describe "conflicting configuration" do
    test "declaring the section and setting parameter_store is an error" do
      error =
        assert_raise DslError, fn ->
          defmodule BothWays do
            use BB, extensions: [BB.Parameter.Store.CubDB.Dsl]

            settings do
              parameter_store {BB.Parameter.Store.Dets, path: "tmp/params.dets"}
            end

            parameter_store_cubdb do
              data_dir "tmp/both_ways"
            end

            topology do
              link :base_link
            end
          end
        end

      assert Exception.message(error) =~ "A robot has one parameter store"
    end

    test "the extension without a section is an error" do
      error =
        assert_raise DslError, fn ->
          defmodule NoSection do
            use BB, extensions: [BB.Parameter.Store.CubDB.Dsl]

            topology do
              link :base_link
            end
          end
        end

      assert Exception.message(error) =~ "would not be persisted"
    end
  end

  describe "persistence across restarts" do
    test "a robot configured by the section reloads tuned parameters" do
      start_supervised!(ViaExtension)

      assert BB.Parameter.get!(ViaExtension, [:kp]) == 1.0
      assert :ok = BB.Parameter.set(ViaExtension, [:kp], 4.5)

      stop_supervised!(ViaExtension)
      start_supervised!(ViaExtension)

      assert BB.Parameter.get!(ViaExtension, [:kp]) == 4.5
    end

    test "a robot configured through settings reloads tuned parameters" do
      start_supervised!(ViaSettings)

      assert :ok = BB.Parameter.set(ViaSettings, [:kp], 7.25)

      stop_supervised!(ViaSettings)
      start_supervised!(ViaSettings)

      assert BB.Parameter.get!(ViaSettings, [:kp]) == 7.25
    end

    test "an untouched parameter keeps its declared default" do
      start_supervised!(ViaExtension)
      stop_supervised!(ViaExtension)
      start_supervised!(ViaExtension)

      assert BB.Parameter.get!(ViaExtension, [:kp]) == 1.0
    end
  end
end
