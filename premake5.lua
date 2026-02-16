-- Shared build scripts from repo_build package.
repo_build = require("omni/repo/build")

-- Repo root
root = repo_build.get_abs_path(".")

-- Run repo_kit_tools premake5-kit that includes Kit-friendly tooling configuration.
kit = require("_repo/deps/repo_kit_tools/kit-template/premake5-kit")
kit.setup_all({ cppdialect = "C++17" })

-- AeroSim Isaac Sim apps
define_app("aerosim.isaac.renderer")
define_app("aerosim.isaac.renderer.dev")
