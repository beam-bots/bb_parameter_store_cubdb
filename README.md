<!--
SPDX-FileCopyrightText: 2026 James Harton

SPDX-License-Identifier: Apache-2.0
-->

<img src="https://github.com/beam-bots/bb/blob/main/logos/beam_bots_logo.png?raw=true" alt="Beam Bots Logo" width="250" />

# BB.Parameter.Store.CubDB

[![CI](https://github.com/beam-bots/bb_parameter_store_cubdb/actions/workflows/ci.yml/badge.svg)](https://github.com/beam-bots/bb_parameter_store_cubdb/actions/workflows/ci.yml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache--2.0-green.svg)](https://opensource.org/licenses/Apache-2.0)
[![Hex version badge](https://img.shields.io/hexpm/v/bb_parameter_store_cubdb.svg)](https://hex.pm/packages/bb_parameter_store_cubdb)
[![Hexdocs badge](https://img.shields.io/badge/docs-hexdocs-purple)](https://hexdocs.pm/bb_parameter_store_cubdb)
[![REUSE status](https://api.reuse.software/badge/github.com/beam-bots/bb_parameter_store_cubdb)](https://api.reuse.software/info/github.com/beam-bots/bb_parameter_store_cubdb)

[CubDB](https://hexdocs.pm/cubdb)-backed parameter persistence for the [Beam Bots](https://github.com/beam-bots/bb) robotics framework.

Tune a gain with `BB.Parameter.set/3`, and it's still there after a reboot.

## Why CubDB

`bb` ships `BB.Parameter.Store.Dets`, which is fine when the machine shuts down
politely. Robots don't always. CubDB stores its data in an append-only, immutable
B-tree, so an unexpected shutdown can't corrupt the database or leave it needing
a repair pass — which matters when the off switch is "it fell over". Keys and
values are arbitrary terms, so parameter paths and `BB.Unit` values are stored
as-is, and writes are flushed to disk as they happen.

## Installation

```bash
mix igniter.install bb_parameter_store_cubdb
```

That adds the extension to your robot and declares a `parameter_store_cubdb`
section, pointing at `/root` on a Nerves project and the build directory
otherwise.

Or add it to `mix.exs` by hand:

```elixir
def deps do
  [
    {:bb_parameter_store_cubdb, "~> 0.1.0"}
  ]
end
```

## Usage

Add the extension to your robot and say where the database lives:

```elixir
defmodule MyRobot.Robot do
  use BB, extensions: [BB.Parameter.Store.CubDB.Dsl]

  parameter_store_cubdb do
    data_dir "/root/my_robot_params"
  end

  parameters do
    group :balance do
      param :kp, type: :float, default: 180.0, min: 0.0, max: 500.0
      param :kd, type: :float, default: 4.0, min: 0.0, max: 50.0
    end
  end

  topology do
    link :base_link
  end
end
```

Then tune away, and the values will be there next boot:

```elixir
iex> BB.Parameter.set(MyRobot.Robot, [:balance, :kp], 200.0)
:ok
```

Declaring the section is all that's needed — it sets the robot's
`parameter_store` setting for you. If you'd rather configure the store directly
and skip the extension, that works too:

```elixir
settings do
  parameter_store {BB.Parameter.Store.CubDB, data_dir: "/root/my_robot_params"}
end
```

## Options

| Option | Default | Description |
|---|---|---|
| `data_dir` | required | Directory to store the database in, created if it doesn't exist |
| `auto_compact` | `true` | Compact automatically. `true`, `false`, or `{min_write_operations, min_dirt_factor}` |
| `auto_file_sync` | `true` | Flush the disk buffer on every write. Turning this off trades durability for write throughput |

## Where to put the data directory

On Nerves, use a path under `/root` — the application data partition. The
firmware's root filesystem is read-only, and `bb` only logs a warning when a
store fails to open, so a robot pointed at an unwritable path will boot with
persistence quietly disabled.

## Bounds aren't rechecked on load

`bb` applies persisted values without revalidating them against each parameter's
`min`/`max`. A value that was in bounds when it was written will still be in
bounds when it's read, so this only bites if something edits the database
directly.

## Licence

Apache-2.0. See `LICENSE.txt`.
