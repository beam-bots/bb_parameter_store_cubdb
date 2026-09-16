# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.Parameter.Store.CubDB do
  @moduledoc """
  CubDB-backed parameter persistence.

  [CubDB](https://hexdocs.pm/cubdb) stores its data in an append-only, immutable
  B-tree, so an unexpected shutdown can't corrupt the database or leave it
  needing a repair pass — which matters for a robot that gets switched off by
  falling over. Keys and values are arbitrary terms, so parameter paths and
  values (including `BB.Unit` structs) are stored as-is.

  ## Usage

  Either declare the `parameter_store_cubdb` section, which wires the store up
  for you:

  ```elixir
  defmodule MyRobot.Robot do
    use BB, extensions: [BB.Parameter.Store.CubDB.Dsl]

    parameter_store_cubdb do
      data_dir "/root/my_robot_params"
    end
  end
  ```

  Or configure the store directly:

  ```elixir
  settings do
    parameter_store {BB.Parameter.Store.CubDB, data_dir: "/root/my_robot_params"}
  end
  ```

  ## Options

  - `:data_dir` - (required) directory to store the database in. Created if it
    doesn't exist.
  - `:auto_compact` - whether to compact the database automatically. `true`,
    `false`, or `{min_write_operations, min_dirt_factor}`. Defaults to `true`.
  - `:auto_file_sync` - flush the disk buffer on every write. Defaults to
    `true`; set it to `false` to trade durability for write throughput.

  ## Where to put the data directory

  On Nerves, use a path under `/root` — the application data partition. The
  firmware's root filesystem is read-only, and a store that fails to open only
  logs a warning, so the robot will boot with persistence silently disabled.

  ## Process lifecycle

  `init/2` starts CubDB with `CubDB.start_link/1`, which links it to the process
  initialising the store — the robot's runtime. The database therefore shares the
  runtime's lifetime, and a CubDB crash takes the runtime with it rather than
  leaving a robot that thinks it is persisting parameters when it isn't.
  """

  @behaviour BB.Parameter.Store

  defstruct [:db, :data_dir]

  @type t :: %__MODULE__{
          db: GenServer.server(),
          data_dir: Path.t()
        }

  @cubdb_options [:auto_compact, :auto_file_sync]

  @impl true
  def init(_robot_module, opts) do
    with {:ok, data_dir} <- fetch_data_dir(opts),
         {:ok, db} <- start_cubdb(data_dir, opts) do
      {:ok, %__MODULE__{db: db, data_dir: data_dir}}
    end
  end

  @impl true
  def load(%__MODULE__{db: db}) do
    {:ok, db |> CubDB.select() |> Enum.to_list()}
  end

  @impl true
  def save(%__MODULE__{db: db}, path, value) do
    CubDB.put(db, path, value)
  end

  @impl true
  def close(%__MODULE__{db: db}) do
    CubDB.stop(db)
    :ok
  end

  defp fetch_data_dir(opts) do
    case Keyword.fetch(opts, :data_dir) do
      {:ok, data_dir} -> {:ok, data_dir}
      :error -> {:error, {:missing_option, :data_dir}}
    end
  end

  defp start_cubdb(data_dir, opts) do
    options =
      opts
      |> Keyword.take(@cubdb_options)
      |> Keyword.put(:data_dir, data_dir)

    case CubDB.start_link(options) do
      {:ok, db} -> {:ok, db}
      {:error, reason} -> {:error, {:cubdb_start_failed, reason}}
    end
  end
end
