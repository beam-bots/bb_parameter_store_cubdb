# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.Parameter.Store.CubDB.Dsl do
  @moduledoc """
  A DSL extension for configuring `BB.Parameter.Store.CubDB`.

  Add the extension to your robot and declare where the database lives:

  ```elixir
  defmodule MyRobot.Robot do
    use BB, extensions: [BB.Parameter.Store.CubDB.Dsl]

    parameter_store_cubdb do
      data_dir "/root/my_robot_params"
      auto_file_sync true
    end
  end
  ```

  Declaring the section is all that's needed — a transformer sets the robot's
  `parameter_store` setting from it. Setting `parameter_store` yourself as well
  is an error, since only one store can win.
  """

  @parameter_store_cubdb %Spark.Dsl.Section{
    name: :parameter_store_cubdb,
    describe: """
    Persist the robot's parameters in a CubDB database.

    Declaring this section sets the robot's `parameter_store` setting to
    `BB.Parameter.Store.CubDB`.
    """,
    examples: [
      """
      parameter_store_cubdb do
        data_dir "/root/my_robot_params"
      end
      """
    ],
    schema: [
      data_dir: [
        type: :string,
        required: true,
        doc:
          "Directory to store the database in, created if it doesn't exist. On Nerves, use a path under `/root`."
      ],
      auto_compact: [
        type: {:or, [:boolean, {:tuple, [:pos_integer, :number]}]},
        required: false,
        default: true,
        doc:
          "Compact the database automatically. `true`, `false`, or `{min_write_operations, min_dirt_factor}`."
      ],
      auto_file_sync: [
        type: :boolean,
        required: false,
        default: true,
        doc:
          "Flush the disk buffer on every write. Turning this off trades durability for write throughput."
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@parameter_store_cubdb],
    transformers: [BB.Parameter.Store.CubDB.Transformers.SetParameterStore]
end
