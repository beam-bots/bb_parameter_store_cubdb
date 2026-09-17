# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.Parameter.Store.CubDB.TestRobots do
  @moduledoc """
  Robot definitions for testing CubDB-backed parameter persistence.

  Each robot keeps its database under `tmp/`, which tests remove between runs.
  """

  defmodule ViaExtension do
    @moduledoc "A robot configured through the `parameter_store_cubdb` section."
    use BB, extensions: [BB.Parameter.Store.CubDB.Dsl]

    parameter_store_cubdb do
      data_dir "tmp/via_extension"
    end

    parameters do
      param :kp, type: :float, default: 1.0, min: 0.0, max: 10.0
    end

    topology do
      link :base_link
    end
  end

  defmodule ViaAppEnv do
    @moduledoc "A robot whose data directory comes from the application environment."
    use BB, extensions: [BB.Parameter.Store.CubDB.Dsl]

    parameter_store_cubdb do
      data_dir Application.compile_env(:bb_parameter_store_cubdb, :params_dir)
    end

    parameters do
      param :kp, type: :float, default: 1.0, min: 0.0, max: 10.0
    end

    topology do
      link :base_link
    end
  end

  defmodule ViaSettings do
    @moduledoc "A robot configured by naming the store directly, with no extension."
    use BB

    settings do
      parameter_store {BB.Parameter.Store.CubDB, data_dir: "tmp/via_settings"}
    end

    parameters do
      param :kp, type: :float, default: 1.0, min: 0.0, max: 10.0
    end

    topology do
      link :base_link
    end
  end
end
