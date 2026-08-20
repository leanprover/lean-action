# General notes
`lean-action` uses git tags and [semantic versioning](https://semver.org/) for release management. For example: `v1`, `v2.7.1`, `v2-beta`.

In short:
- If a release changes the API of the inputs to `lean-action` or contains changes which would break backwards compatibility, bump the major version.
- If a release introduces new features or changes the inputs API which does not break backwards compatibility (e.g. adds a new input which doesn't affect the other inputs), bump the minor version.
- For bug fixes, bump the patch version.

A major version tag is maintained for each version which points to the latest version of `lean-action`. Users will most often use `lean-action` with this major version tag. For example, if the latest version of `lean-action` is `v2.7.1`, `v2` should point to `v2.7.1`.

For more information about releasing GitHub actions see the [Using tags for release management](https://docs.github.com/en/actions/creating-actions/about-custom-actions#using-tags-for-release-management) section of the GitHub custom actions documentation.

## Creating a release
Releases are automated by the `Release` workflow (`.github/workflows/release.yml`).

To create a release, run the `Release` workflow on the ref to release (usually `main`)
with the new version number (e.g. `v2.7.1`) as input.

The workflow:
- Validates the version number and checks the `## Unreleased` section of `CHANGELOG.md` is not empty.
- Runs the functional tests on the release ref and blocks the release if they fail.
- Creates a GitHub release and a `v{RELEASE_VERSION}` git tag with release notes taken from the `## Unreleased` section of `CHANGELOG.md`.
- Moves the major version tag (e.g. `v2`) to the new release, creating it first for a major release.
- Opens a PR which stamps `CHANGELOG.md` with the release version and date and, for a major release, updates the `leanprover/lean-action@v{MAJOR_VERSION}` references in `README.md`.
- Writes a release announcement to the workflow run summary.

After the workflow completes:
- Merge the PR opened by the workflow.
- Post the release announcement from the workflow run summary in the `general/lean-action` Zulip topic.

In the rare case a release needs commits which are not on `main` (e.g. a patch release which cherry-picks a fix), create a `release/v{RELEASE_VERSION}` branch, push the commits there, run the `Release` workflow on that branch, and merge the branch back into `main` afterwards.

## Special notes for major releases
- Clearly outline in the `README.md` and in communication to the Lean community what the migration strategy is to the new version if it is more involved than bumping the version number in `uses: leanprover/lean-action@v{VERSION}`.
