# General notes
`lean-action` use git tags and [semantic versioning](https://semver.org/) for release management. For example: `v1`, `v2.7.1`, `v2-beta`.

In short:
- If a release changes the API of the inputs to `lean-action` or contains changes which would break backwards compatibility, bump the major version.
- If a release introduces new features or changes the inputs API which does not break backwards compatibility (e.g. adds a new input which doesn't affect the other inputs), bump the minor version.
- For bug fixes, bump the patch version.

For more information about releasing GitHub actions see the [Using tags for release management](https://docs.github.com/en/actions/creating-actions/about-custom-actions#using-tags-for-release-management) section of the GitHub custom actions documentation.

## Steps to create a release
- Create an issue to track creating the release.
- Create a `release/v{RELEASE_VERSION}` branch (e.g. `release/v2.7.1`).
- Test `lean-action` by pointing an existing test repository to the new version with `uses: leanprover/lean-action@v{RELEASE_VERSION}`.
- Make any minor commits related to the release on the release branch.
- Once the release has been validated, create a git tag `v{RELEASE_VERSION}` (e.g `v2.7.1`).
- If you made additional commits on the release branch, merge the release branch back into `main`.
- Replace all instances of `leanprover/leanaction@{PREVIOUS_RELEASE_VERSION}` in `README.md` with `leanprover/leanaction@{NEW_RELEASE_VERSION}`.
    - Quickly do this with `sed -i 's/leanprover\/lean-action@v2/leanprover\/lean-action@v3/g' README.md` if releasing `v3`.
- Make an announcement to the Lean community.

## Special notes for major releases
If upgrading includes changes to the input API or other breaking changes which would require a migration strategy beyond bumping the version number in `uses: leanprover/leanaction@v{VERSION}`, clearly outline the necessary migration strategy in the communication to the Lean community and add a section to the `README.md` with details.
