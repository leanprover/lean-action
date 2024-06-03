## Contribution Guidelines
Follow Lean's [Commit Convention](https://github.com/leanprover/lean4/blob/master/doc/dev/commit_convention.md).

For more information see the [PR Submission](https://github.com/leanprover/lean4/blob/master/CONTRIBUTING.md#pr-submission) section in lean4's CONTRIBUTING.md.

Note this key detail:
> Follow the commit convention: Pull requests are squash merged, and the commit message is taken from the pull request title and body, so make sure they adhere to the commit convention. Put questions and extra information, which should not be part of the final commit message, into a first comment rather than the Pull Request description. Because the change will be squashed, there is no need to polish the commit messages and history on the branch.

If release notes should include changes introduced by your PR, add a bullet to the `## Unreleased` section in `CHANGELOG.md`.

## Testing
The `lean-action` repository contains a set of functional tests
to ensure changes do not introduce regressions to existing functionality.

The `.github/functional_tests` directory contains GitHub actions
which correspond to functional test cases for `lean-action`. 

As of now, the only entry point for functional tests is the `.github/workflow/functional_tests.yml` workflow,
which runs when a PR proposes changes to critical files in the `lean-action` repository.
In the future, we will likely introduce additional entry points for tests,
such as a more comprehensive test suite for release candidates.

### Creating a new test
When introducing new functionality to `lean-action`, consider creating a new functional test.
Here are the steps to create a new test:
- Create a new action corresponding to a test.
    - Create a subdirectory named after the test in `.github/functional_tests`.
    - Create an `action.yml` GitHub action file within the directory, which initializes the test and calls `lean-action`.
        - Write a meaningful description of what use cases your test covers.
        - If appropriate, you can parameterize your test with action inputs for more flexibility (see the `.github/functional_tests/lake_init` directory for an example).
        - For more information on the action syntax, see [creating a composite action](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action).
- Create a new job in `.github/workflows/functional_tests.yml` with a call to the newly created action.

### Running functional tests locally with `act`
`lean-action` developers can leverage [act](https://github.com/nektos/act) to run tests locally.

Here are two useful commands:
- Run all tests locally: `act workflow_dispatch '.github/workflows/functional_tests.yml'`.
- Run a specific test by running a job within the `functional_tests.yml` workflow:
`act workflow_dispatch -j {job-name} -W '.github/workflows/functional_tests.yml'`,
e.g., `act workflow_dispatch -j lake-test -W '.github/workflows/functional_tests.yml'`
