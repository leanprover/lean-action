# Changelog

All notable changes to `lean-action` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## v1.0.0 - 2024-07-20
### Added

- new `auto-config` input
to specify if `lean-action` should use the Lake workspace
to automatically determine which CI features to run, i.e., `lake build`, `lake test`, `lake lint`.
- new `build` input to specify if `lean-action` should run `lake build`
- new `lint` input to specify if `lean-action` should run `lake lint`
- parameterize functional tests by Lean toolchain to allow for testing `lean-action` on any Lean version.

### Changed

- `test` input now defaults to `auto-config`.
Users can still specify `test: true` to force `lean-action` to run `lake test`.
- removed `lint-module` input.
Users should now use a `@[lint_driver]` to integrate with the `Batteries` testing framework.

### Fixed

- improved GitHub cache keys
to make caching more efficient and avoid edge cases when upgrading Lean version.

## v1-beta.1 - 2024-06-21

### Added

- new `use-github-cache` input to specify if `lean-action` should use `actions/cache` to cache the `.lake` folder
- `build-status` and `test-status` output parameters
- new `lake-package-directory` input to specify the directory to run Lake commands.
This input will enable users to use `lean-action` when Lake packages are contained in repository subdirectories.
- new `auto-config` input to configure `lean-action` to use the Lake workspace to decide which steps to run

### Changed

- upgrade elan version to `v3.1.1`
- run `lake check-test` before running `lake test`
- improved log readability with explicit log group naming and additional white space

### Fixed

- remove misleading .toml error message in mathlib detection
- remove `elan-init` file after elan installation

## v1-beta.0 - 2024-05-21

### Added

- logs are grouped by step for better readability
- new `build-args` input to specify arguments to pass to `lake build`
- install elan step logs `lean --version` and `lake --version`

### Changed

- `lean-action` no longer contains an `actions/checkout` step
- `mathlib-cache` renamed to `get-mathlib-cache`

### Fixed

- improved default value for `get-mathlib-cache`

## v1-alpha - 2024-05-12

### Added

- build packages with `lake build`
- run tests with `lake test`
- automatically detect `mathlib` dependency and run `lake exe get cache`
- detect [Reservoir eligibility](https://reservoir.lean-lang.org/inclusion-criteria)
- check for environment hacking with lean4checker
