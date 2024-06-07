# Changelog
All notable changes to `lean-action` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added
- new `use-github-cache` input to specify if `lean-action` should use `actions/cache` to cache the `.lake` folder
- `BUILD_STATUS` and `TEST_STATUS` output parameters

### Changed
- upgrade elan version to `v3.1.1`

## v1-beta - 2024-05-21

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