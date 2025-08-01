# lean-action - CI for Lean Projects

lean-action provides steps to build, test, and lint [Lean](https://github.com/leanprover/lean4) projects on GitHub

## Quick Setup

To setup `lean-action` to run on pushes and pull request in your repo, create the following `ci.yml` file the `.github/workflows`

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
      - uses: leanprover/lean-action@v1
```

> [!IMPORTANT]
`lean-action` is tested on `ubuntu-latest`, `macos-latest`, and `windows-latest` GitHub-hosted runners.
We recommend using one of these runners for the best experience,
however if you encounter an issue when using a different runner, please still open an issue.

## Caching `.lake` directory with GitHub's `actions\cache`
By default, `lean-action` uses [`actions\cache`](https://github.com/actions/cache) to cache the `.lake` directory and speed up builds.

> [!NOTE]
GitHub caching is distinct from Mathlib caching with `lake exe cache get`

### Cache keys
`lean-action` uses [cache keys](https://github.com/actions/cache?tab=readme-ov-file#creating-a-cache-key) to save and restore caches.

First it uses a primary key,
composed of the runner operating system, the runner architecture (X86, X64, ARM, ARM64), the Lake manifest, and the git commit hash,
to save/restore caches from an exact git commit.

If there is no primary key cache hit, `lean-action` uses a fallback key, 
composed of the operating system, the architecture, and the Lake manifest but not the git commit hash,
to restore a cache from a previous commit.

### Troubleshooting problems with caching
Because caches are shared across different jobs,
caching build files can lead to unexpected behavior and errors.

To determine if the GitHub cache is causing problems you can disable caching with the `use-github-cache` input.
```yml
- uses: leanprover/lean-action@v1
  with:
    use-github-cache: false
```

For more complex workflows, you may want more control over how the `actions\cache` caches the build in your workflow,
(.e.g., modifying the cache key to respect a build matrix)
you can wrap `lean/action` with `use-github-cache: false` in your own call to `actions\cache`.

## Configuring which features `lean-action` runs

Most use cases only require a subset of `lean-action`'s features
in a specific GitHub workflow.
Additionally, you may want to break up usage of `lean-action`
across multiple workflows with different triggers,
e.g., one workflow for PRs and another workflow scheduled by a cron job.

To support these use cases,
`lean-action` provides inputs to specify the subset of desired features of `lean-action`.

### Directly specifying a desired feature with specific feature inputs

Each feature of `lean-action` has a corresponding input which users can set to `true` or `false`.
Specific feature inputs have the highest precedence
when `lean-action` determines which features to run.
When a feature input is set `lean-action` will always try to run the corresponding step.
If `lean-action` is unable to successfully run the step, `lean-action` will fail.

`lean-action` provides the following feature inputs:

- `build`
- `test`
- `lint`
- `mk_all-check`
- `check-reservoir-eligibility`
- `lean4checker`

### Automatic configuration

After feature inputs, `lean-action` uses the `auto-config` input
to determine if it should use the Lake workspace to decide which steps to run automatically.
When `auto-config: true`, `lean-action` will use the Lake workspace to detect targets
and run the corresponding Lake command.
When `auto-config: false`, `lean-action` will only run features specified directly through specific feature inputs.
Users can combine `auto-config` with specific feature inputs to override the automatic configuration of `lean-action`.

`lean-action` can automatically configure the following features:

- `build`
- `test`
- `lint`

### Breaking up `lean-action` across workflows

Sometimes it is useful to break up usage of `lean-action`
across multiple workflows with different triggers,
e.g., one workflow for PRs and another workflow scheduled by a cron job.
`auto-config: false` allows users to run only a specific subset of features of `lean-action`.

For example, run only `lean4checker` in a cron job workflow:

```yaml
- name: "run `lean-action` with only `lean4checker: true`"
  id: lean-action
  uses: leanprover/lean-action@v1
  with:
    auto-config: false
    lean4checker: true
```

### Differences between using `auto-config` and feature inputs

When you specify a feature with a feature input, `lean-action` will fail if it can't complete that step.
However, if you use `auto-config`,
`lean-action` will only fail if it detects a target in the Lake workspace and the detected target fails.

For example, if the `lakefile.lean` contains an improperly configured `test_driver` target
and you configure `lean-action` with `test: true`, `lean-action` will fail.
However the same improperly configured `test_driver` may not cause a `lean-action` failure with `auto-config: true`,
because `lean-action` may not detect the `test_driver` in the Lake workspace.

To be certain `lean-action` runs a step, specify the desire feature with a feature input.

## Customization

`lean-action` provides optional configuration inputs to customize the behavior for your specific workflow.

```yaml
- uses: leanprover/lean-action@v1
  with:
    
    # Automatically configure `lean-action` based on the Lake workspace.
    # When set to "true", `lean-action` will use the Lake workspace to determine
    # the set of features to run on the repository, such as `lake build` and `lake test`.
    # Even when set to "true", the user can still override the auto configuration
    # with the `build` and `test` inputs.
    # Allowed values: "true" or "false".
    # Default: "true"
    auto-config: ""
    
    # Run `lake build`.
    # Note, this input takes precedence over `auto-config`.
    # Allowed values: "true" | "false" | "default".
    build: ""

    # Run `lake test`.
    # Note, this input takes precedence over `auto-config`.
    # Allowed values: "true" | "false" | "default".
    test: ""
    
    # Run `lake lint`.
    # Note, this input takes precedence over `auto-config`.
    # Allowed values: "true" | "false" | "default".
    lint: ""

    # Check all files are imported with `lake exe mk_all --check`.
    # Allowed values: "true" | "false".
    mk_all-check: ""

    # Build arguments to pass to `lake build {build-args}`.
    # For example, `build-args: "--quiet"` will run `lake build --quiet`.
    # By default, `lean-action` calls `lake build` with no arguments.
    build-args: ""

    # By default, `lean-action` attempts to automatically detect a Mathlib dependency and run `lake exe cache get` accordingly.
    # Setting `use-mathlib-cache` will override automatic detection and run (or not run) `lake exe cache get`.
    # Project must be downstream of Mathlib to use the Mathlib cache.
    # Allowed values: "true" | "false" | "auto".
    # Default: "auto"
    use-mathlib-cache: ""

    # Check if the repository is eligible for the Reservoir.
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
    # Default: "true"
    use-github-cache: ""

    # The directory where `lean-action` will look for a Lake package and run `lake build`, etc.
    # Allowed values: a valid directory containing a Lake package.
    # If lake-package-directory is not provided, `lean-action` will use the root directory of the repository by default.
    lake-package-directory: ""

    # Always reinstall the Lean toolchain if it is a transient one, hosted on the lean4-pr-releases repository.
    # This ensures that CI always uses the latest build of that toolchain.
    # This setting only applies to `lean4-pr-releases/pr-release-XXXX` toolchains:
    # regular Lean toolchain releases remain cached.
    # The toolchain version is determined from the `lean-toolchain` file.
    # Allowed values: "true" | "false".
    # Default: "false"
    reinstall-transient-toolchain: ""
```

## Output Parameters

`lean-action` provides the following output parameters for downstream steps:

- `build-status`
  - Values: "SUCCESS" | "FAILURE" | ""
- `test-status`
  - Values: "SUCCESS" | "FAILURE" | ""
- `lint-status`
  - Values: "SUCCESS" | "FAILURE" | ""
- `mk_all-status`
  - Values: "SUCCESS" | "FAILURE" | ""

Note, a value of empty string indicates `lean-action` did not run the corresponding feature.

### Example: Use `test-status` output parameter in downstream step

```yaml
- name: "run `lean-action` with `lake test`" 
  id: lean-action
  uses: leanprover/lean-action@v1
  continue-on-error: true
  with:
    test: true

- name: log `lean-action` `test-status` output
  env:
    TEST_STATUS: ${{ steps.lean-action.outputs.test-status }}
  run: echo "Test status: $TEST_STATUS"
```

## Additional Examples

### Check package for reservoir eligibility

```yaml
- uses: leanprover/lean-action@v1
  with:
    check-reservoir-eligibility: true
```

### Don't run `lake test` or use Mathlib cache

```yaml
- uses: leanprover/lean-action@v1
  with:
    test: false
    use-mathlib-cache: false
```

### Run lake build with `--wfail`

```yaml
- uses: leanprover/lean-action@v1
  with:
    build-args: "--wfail"
```

### Run additional steps after `lean-action` using the Lean environment

After calling `lean-action` you can leverage the Lean environment in later workflow steps.

For example, `leanprover-community/import-graph` uses the setup from `lean-action` to test the `graph` executable with `lake exe graph`:

```yaml
steps:
  - uses: leanprover/lean-action@v1
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
