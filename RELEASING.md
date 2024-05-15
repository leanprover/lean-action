# General notes
`lean-action` use git tags and [semantic versioning](https://semver.org/) for release management. For example: `v1`, `v2.7.1`, `v2-beta`.

In short:
- If a release changes the API of the inputs to `lean-action` or contains changes which would break backwards compatibility, bump the major version.
- If a release introduces new features or changes the inputs API which does not break backwards compatibility (e.g. adds a new input which doesn't affect the other inputs), bump the minor version.
- For bug fixes, bump the patch version.

A major version tag is maintained for each version which points to the latest version of `lean-action`. Users will most often use `lean-action` with this major version tag. For example, if the latest version of `lean-action` is `v2.7.1`, `v2` will point to `v2.7.1`.

For more information about releasing GitHub actions see the [Using tags for release management](https://docs.github.com/en/actions/creating-actions/about-custom-actions#using-tags-for-release-management) section of the GitHub custom actions documentation.

## Steps to create a release
- Create an issue to track creating the release.
- Create a `release/v{RELEASE_VERSION}` branch (e.g. `release/v2.7.1`).
- Test `lean-action` by pointing an existing test repository to the new version with `uses: leanprover/lean-action@v{RELEASE_VERSION}`.
- Make any minor commits related to the release on the release branch.
- Once the release has been validated, create a new release with release notes and a git tag `v{RELEASE_VERSION}` (e.g `v2.7.1`).
- In the case of a minor or patch version, move the major version tag to the latest version
- If you made additional commits on the release branch, merge the release branch back into `main`.
- Make an announcement to the Lean community.

## Special notes for major releases
- Replace all instances of `leanprover/leanaction@{PREVIOUS_MAJOR_RELEASE_VERSION}` in `README.md` with `leanprover/lean-action@{NEW_MAJOR_RELEASE_VERSION}`.
    - Quickly do this with `sed -i 's/leanprover\/lean-action@v2/leanprover\/lean-action@v3/g' README.md` if releasing `v3`.
- Clearly outline in the `README.md` and in communication to the Lean community what the migration strategy is to the new version if it is more involved than bumping the version number in `uses: leanprover/leanaction@v{VERSION}`.
