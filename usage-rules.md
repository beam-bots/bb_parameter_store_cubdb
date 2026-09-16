<!--
SPDX-FileCopyrightText: 2026 James Harton

SPDX-License-Identifier: Apache-2.0
-->

# BB.Parameter.Store.CubDB Usage Rules

`bb_parameter_store_cubdb` persists a robot's parameters in a
[CubDB](https://hexdocs.pm/cubdb) database, implementing the
`BB.Parameter.Store` behaviour from [Beam Bots](https://hexdocs.pm/bb).
For BB framework basics, see `bb`'s rules (`mix usage_rules.sync <file> bb:all`);
this file covers only what's specific to the store.

## Core principles

1. **Declare the section, not the setting.** Adding the extension and a
   `parameter_store_cubdb` section is the whole configuration — a transformer
   sets the robot's `parameter_store` for you. Doing both is a compile error.
2. **One store per robot.** A robot has a single `parameter_store`. This package
   doesn't replace `BB.Parameter.Store.Dets`; pick one.
3. **Every `BB.Parameter.set/3` is a disk write.** Writes are flushed as they
   happen. That's the point — but don't drive `set/3` from a control loop.

## Configuring a robot

```elixir
defmodule MyRobot.Robot do
  use BB, extensions: [BB.Parameter.Store.CubDB.Dsl]

  parameter_store_cubdb do
    data_dir "/root/my_robot_params"
  end

  parameters do
    group :balance do
      param :kp, type: :float, default: 180.0, min: 0.0, max: 500.0
    end
  end

  topology do
    link :base_link
  end
end
```

`data_dir` is required and is created if it doesn't exist. `auto_compact`
(default `true`) and `auto_file_sync` (default `true`) are passed through to
CubDB.

To use the store without the extension — e.g. when the directory comes from
somewhere else — name it directly and skip the section:

```elixir
settings do
  parameter_store {BB.Parameter.Store.CubDB, data_dir: "/root/my_robot_params"}
end
```

## Do

- Put `data_dir` under `/root` on Nerves. That's the application data
  partition; the rest of the firmware's filesystem is read-only.
- Let persisted values win over DSL defaults. That's `bb`'s load order, and it's
  what makes tuning stick.
- Set `auto_file_sync false` only if you've measured a write throughput problem,
  and understand that recent writes can then be lost on a hard power cut.

## Don't

- **Don't expect a bad `data_dir` to fail loudly.** `bb` logs a warning when a
  store can't open and carries on, so the robot boots with persistence off.
  Check the path.
- **Don't edit the database out of band.** `bb` applies persisted values without
  rechecking each parameter's `min`/`max`, so a hand-edited value can put a
  parameter out of bounds.
- **Don't add the extension without the section.** It's a compile error, on
  purpose: the alternative is a robot that looks persistent and isn't.
