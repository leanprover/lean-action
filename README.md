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
      # uses lean standard action with all default input values
      - uses: leanprover/lean-action
```

## Usage

```yaml
- uses: leanprover/lean-action
  with:
    # Run lake test.
    # Allowed values: "true" or "false".
    # Default: true
    test: true

    # Run "lake exe cache get" before build.
    # Project must be downstream of Mathlib.
    # Allowed values: "true" or "false".
    # If mathlib-cache input is not provided, the action will attempt to automatically detect if the project is downstream of Mathlib.
    mathlib-cache: ""

    # Run "lake exe runLinter" on the specified module.
    # Project must be downstream of Batteries.
    # Allowed values: name of module to lint.
    # If lint-module input is not provided, linter will not run.
    lint-module: ""

    # Check if the repository is eligible for the reservoir.
    # Allowed values: "true" or "false".
    # Default: false
    check-reservoir-eligibility: false
    
    # Check environment with lean4checker.
    # Lean version must be 4.8 or higher.
    # The version of lean4checker is automatically detected using `lean-toolchain`.
    # Allowed values: "true" or "false".
    # Default: false
    lean4checker: false 
```

## Examples

### Lint the `MyModule` module and check package for reservoir eligibility

```yaml
- uses: leanprover/lean-action
  with:
    lint-module: MyModule
    check-reservoir-eligibility: true
```

### Don't run `lake test` or use Mathlib cache

```yaml
- uses: leanprover/lean-action
  with:
    test: false
    mathlib-cache: false
```

## Keep the action updated with `dependabot`

In order to receive notification when this action is updated (and any others used in your repo), add the file `.github/dependabot.yml` with the contents:

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions" 
    directory: "/"
    schedule:
      interval: "daily"
```

See the [dependabot documentation](https://docs.github.com/code-security/dependabot/dependabot-version-updates/configuration-options-for-the-dependabot.yml-file) for all configuration options.
