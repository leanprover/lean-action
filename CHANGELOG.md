# Changelog
All notable changes to `lean-action` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## v1-beta.1 - 2024-06-21

### Added
- new `use-github-cache` input to specify if `lean-action` should use `actions/cache` to cache the `.lake` folder
- `build-status` and `test-status` output parameters
- new `lake-package-directory` input to specify the directory to run Lake commands. 
This input will enable users to use `lean-action` when Lake packages are contained in repository subdirectories.

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