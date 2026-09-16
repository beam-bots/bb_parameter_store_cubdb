# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.Parameter.Store.CubDBTest do
  use ExUnit.Case, async: true

  alias BB.Parameter.Store.CubDB, as: Store

  defmodule FakeRobot do
    @moduledoc false
  end

  describe "init/2" do
    @tag :tmp_dir
    test "creates the data directory if it doesn't exist", %{tmp_dir: tmp_dir} do
      data_dir = Path.join(tmp_dir, "does_not_exist_yet")

      assert {:ok, store} = Store.init(FakeRobot, data_dir: data_dir)
      assert File.dir?(data_dir)

      Store.close(store)
    end

    test "requires a data directory" do
      assert {:error, {:missing_option, :data_dir}} = Store.init(FakeRobot, [])
    end

    @tag :tmp_dir
    test "passes CubDB options through", %{tmp_dir: tmp_dir} do
      assert {:ok, store} =
               Store.init(FakeRobot,
                 data_dir: tmp_dir,
                 auto_file_sync: false,
                 auto_compact: false
               )

      assert %{auto_file_sync: false, auto_compact: false} = :sys.get_state(store.db)

      Store.close(store)
    end
  end

  describe "save/3 and load/1" do
    @tag :tmp_dir
    test "round-trips parameter paths and values", %{tmp_dir: tmp_dir} do
      {:ok, store} = Store.init(FakeRobot, data_dir: tmp_dir)

      assert :ok = Store.save(store, [:balance, :kp], 180.0)
      assert :ok = Store.save(store, [:max_speed], 2.0)

      assert {:ok, loaded} = Store.load(store)
      assert Enum.sort(loaded) == [{[:balance, :kp], 180.0}, {[:max_speed], 2.0}]

      Store.close(store)
    end

    @tag :tmp_dir
    test "overwrites a previously saved value", %{tmp_dir: tmp_dir} do
      {:ok, store} = Store.init(FakeRobot, data_dir: tmp_dir)

      :ok = Store.save(store, [:balance, :kp], 1.0)
      :ok = Store.save(store, [:balance, :kp], 2.0)

      assert {:ok, [{[:balance, :kp], 2.0}]} = Store.load(store)

      Store.close(store)
    end

    @tag :tmp_dir
    test "returns an empty list for a fresh database", %{tmp_dir: tmp_dir} do
      {:ok, store} = Store.init(FakeRobot, data_dir: tmp_dir)

      assert {:ok, []} = Store.load(store)

      Store.close(store)
    end

    @tag :tmp_dir
    test "stores unit values as terms", %{tmp_dir: tmp_dir} do
      import BB.Unit

      {:ok, store} = Store.init(FakeRobot, data_dir: tmp_dir)
      reach = ~u(0.5 meter)

      :ok = Store.save(store, [:reach], reach)

      assert {:ok, [{[:reach], ^reach}]} = Store.load(store)

      Store.close(store)
    end
  end

  describe "durability" do
    @tag :tmp_dir
    test "values survive reopening the database", %{tmp_dir: tmp_dir} do
      {:ok, store} = Store.init(FakeRobot, data_dir: tmp_dir)
      :ok = Store.save(store, [:balance, :kp], 180.0)
      :ok = Store.close(store)

      {:ok, reopened} = Store.init(FakeRobot, data_dir: tmp_dir)

      assert {:ok, [{[:balance, :kp], 180.0}]} = Store.load(reopened)

      Store.close(reopened)
    end

    @tag :tmp_dir
    @tag :capture_log
    test "values survive the database process being killed", %{tmp_dir: tmp_dir} do
      {:ok, store} = Store.init(FakeRobot, data_dir: tmp_dir)
      :ok = Store.save(store, [:balance, :kp], 180.0)

      Process.unlink(store.db)
      Process.exit(store.db, :kill)
      refute Process.alive?(store.db)

      {:ok, reopened} = Store.init(FakeRobot, data_dir: tmp_dir)

      assert {:ok, [{[:balance, :kp], 180.0}]} = Store.load(reopened)

      Store.close(reopened)
    end
  end
end
