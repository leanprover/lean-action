# lean-action - CI for Lean Projects

lean-action provides steps to build, test, and lint [Lean](https://github.com/leanprover/lean4) projects on Github

## Quick Setup

To setup lean-action to run on pushes and pull request in your repo, create the following `ci.yml` file the `.github/workflows`

```yml
name: CI

on:
  push:
    branches: ["main"] # replace "main" with the default branch
  pull_request:
    branches: ["main"]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4
      # uses lean standard action with all default input values
      - uses: leanprover/lean-action@v1-beta
```

## Usage

```yaml
- uses: leanprover/lean-action@v1-beta
  with:
    # Run lake test.
    # Allowed values: "true" | "false".
    # Default: true
    test: ""

    # Build arguments to pass to `lake build {build-args}`.
    # For example, `build-args: "--quiet"` will run `lake build --quiet`.
    # By default, `lean-action` calls `lake build` with no arguments
    build-args: ""

    # By default, `lean-action` attempts to automatically detect a Mathlib dependency and run `lake exe cache get` accordingly.
    # Setting `use-mathlib-cache` will override automatic detection and run (or not run) `lake exe cache get`.
    # Project must be downstream of Mathlib to use the Mathlib cache.
    # Allowed values: "true" | "false" | "auto".
    # Default: "auto"
    use-mathlib-cache: ""

    # Run "lake exe runLinter {lint-module}" on the specified module.
    # Project must be downstream of Batteries.
    # Allowed values: name of module to lint.
    # By default, `lean-action` will not run the linter.
    lint-module: ""

    # Check if the repository is eligible for the reservoir.
    # Allowed values: "true" | "false".
    # Default: "false"
    check-reservoir-eligibility: ""
    
    # Check environment with lean4checker.
    # Lean version must be 4.8 or higher.
    # The version of lean4checker is automatically detected using `lean-toolchain`.
    # Allowed values: "true" | "false".
    # Default: "false"
    lean4checker: ""
    
    # Enable GitHub caching.
    # Allowed values: "true" or "false".
    # If use-github-cache input is not provided, the action will use GitHub caching by default.
    use-github-cache: true
```

## Examples

### Lint the `MyModule` module and check package for reservoir eligibility

```yaml
- uses: leanprover/lean-action@v1-beta
  with:
    lint-module: MyModule
    check-reservoir-eligibility: true
```

### Don't run `lake test` or use Mathlib cache

```yaml
- uses: leanprover/lean-action@v1-beta
  with:
    test: false
    use-mathlib-cache: false
```

### Run lake build with `--wfail`

```yaml
- uses: leanprover/lean-action@v1-beta
  with:
    build-args: "--wfail"
```

### Run additional steps after `lean-action` using the Lean environment

After calling `lean-action` you can leverage the Lean environment in later workflow steps.

For example, `leanprover-community/import-graph` uses the setup from `lean-action` to test the `graph` executable with `lake exe graph`:

```yaml
steps:
  - uses: leanprover/lean-action@v1-beta
    with:
      check-reservoir-eligibility: true
  # use setup from lean-action to perform the following steps
  - name: verify `lake exe graph` works
    run: |
      lake exe graph
      rm import_graph.dot
```

## Projects which use `lean-action`
- [leanprover-community/aesop](https://github.com/leanprover-community/aesop/blob/master/.github/workflows/build.yml#L16)
- [leanprover-community/import-graph](https://github.com/leanprover-community/import-graph/blob/main/.github/workflows/build.yml#L8)

## Keep the action updated with `dependabot`
Because Lean is under heavy development, changes to Lean or Lake could break outdated versions of `lean-action`. You can configure [dependabot](https://docs.github.com/en/code-security/dependabot/dependabot-version-updates/about-dependabot-version-updates) to automatically create a PR to update `lean-action` when a new stable version is released. 

Here is an example `.github/dependabot.yml` which configures `dependabot` to check daily for updates to all GitHub actions in your repository:

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions" 
    directory: "/"
    schedule:
      interval: "daily"
```

See the [dependabot documentation](https://docs.github.com/code-security/dependabot/dependabot-version-updates/configuration-options-for-the-dependabot.yml-file) for all configuration options.
