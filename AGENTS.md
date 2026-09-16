<!--
SPDX-FileCopyrightText: 2026 James Harton

SPDX-License-Identifier: Apache-2.0
-->

# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Project Overview

`bb_parameter_store_cubdb` persists a Beam Bots robot's parameters in a
[CubDB](https://hexdocs.pm/cubdb) database. It implements the
`BB.Parameter.Store` behaviour from core `bb`, and ships a DSL extension so a
robot can be configured in one place.

Core `bb` already has `BB.Parameter.Store.Dets`. This package is additive, not a
replacement: DETS is fine for a machine that shuts down cleanly, and CubDB's
append-only B-tree is what you want when the off switch is the robot falling
over.

## Architecture

```
lib/bb/parameter/store/
├── cub_db.ex                              # The BB.Parameter.Store implementation
└── cub_db/
    ├── dsl.ex                             # Spark extension: the parameter_store_cubdb section
    └── transformers/
        └── set_parameter_store.ex         # Wires the section into settings.parameter_store
```

### How the extension works

The extension is sugar over the `{Module, opts}` seam core already has. The
transformer reads the `parameter_store_cubdb` section and sets the robot's
`settings`/`parameter_store` option with `Spark.Dsl.Transformer.set_option/4`,
which core reads back through `Spark.Dsl.Extension.get_opt/3`. Nothing in `bb`
knows this package exists, and the store module itself is DSL-unaware — it just
receives a keyword list in `init/2`.

Two consequences worth remembering:

- `set_option/4` bypasses the target section's schema, so the
  `parameter_store_cubdb` section's own schema is the only validation there is.
- The checks live in the **transformer**, not a verifier. Spark reports verifier
  errors with `IO.warn` (see `Spark.Dsl.__before_compile__`), so a verifier
  would leave a misconfigured robot compiling with a warning — no good when the
  failure mode is "your tuning silently isn't saved". Transformer errors raise.

### This is the first satellite DSL extension

Every other `bb_*` package integrates by handing a module to an existing DSL
slot. `use BB, extensions: [...]` works because `BB` doesn't override Spark's
`untyped_extensions?`, which defaults to `true`. No change to `bb` was needed.

## Build and Test Commands

```bash
mix check --no-retry    # Run all checks (compile, test, format, credo, dialyzer, spark, reuse)
mix test                # Run tests
mix test path/to/test.exs:42  # Run single test at line
mix format              # Format code
mix spark.cheat_sheets  # Regenerate documentation/dsls after changing the DSL
```

Always prefer `mix check --no-retry` over running individual tools.

After changing the DSL section, run `mix spark.formatter` and
`mix spark.cheat_sheets` — `mix check` fails if either is stale.

## Testing Notes

- Store callbacks are tested directly with `@tag :tmp_dir` for isolation.
- The DSL and persistence-across-restart tests use robots in
  `test/support/test_robots.ex`, whose databases live under `tmp/` (removed
  between tests). They're `async: false` because of the shared directory.
- Compile-time failures are tested with `assert_raise Spark.Error.DslError`
  around a `defmodule`.

## Gotchas

- `init/2` runs inside the robot's runtime process, so `CubDB.start_link/1`
  links the database to the runtime. That's deliberate: a CubDB crash should
  take the runtime with it rather than leave a robot that thinks it's persisting
  parameters.
- `bb` only logs a warning when a store fails to open, so a bad `data_dir` means
  persistence is silently off. On Nerves the writable partition is `/root`.
- `bb` doesn't recheck `min`/`max` when applying persisted values — it writes
  them straight to ETS. Don't work around that here; it belongs in core.
