# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

import Config

config :git_ops,
  mix_project: Mix.Project.get!(),
  changelog_file: "CHANGELOG.md",
  repository_url: "https://github.com/beam-bots/bb_parameter_store_cubdb",
  manage_mix_version?: true,
  manage_readme_version: "README.md",
  version_tag_prefix: "v"

# Read at compile time by the ViaAppEnv test robot, which exercises the
# configure-the-directory-from-application-env pattern the README describes.
# Not scoped to :test, because test/support is compiled in :dev too.
config :bb_parameter_store_cubdb, params_dir: "tmp/via_app_env"
