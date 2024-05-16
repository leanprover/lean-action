# Changelog
All notable changes to `lean-action` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added
- logs are grouped by step for better readability

### Changed
- `lean-action` no longer contains an `actions/checkout` step

## v1-alpha - 2024-05-12

### Added
- build packages with `lake build`
- run tests with `lake test`
- automatically detect `mathlib` dependency and run `lake exe get cache`
- detect [Reservoir eligibility](https://reservoir.lean-lang.org/inclusion-criteria)
- check for environment hacking with  lean4checker