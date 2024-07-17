Before creating an issue with this template, 
- replace `{{MAJOR_RELEASE}}` with the current major release, e.g., `v1`.
- replace `{{SPECIFIC_RELEASE}}` with the specific release tag, e.g., `v1.0.0` or `v1.1.3`.
- remove any todos that start with {{REMOVE IF NOT MAJOR RELEASE}} if this isn't a major release.

# {{SPECIFIC_RELEASE}}
- [ ] Create a `release/{{SPECIFIC_RELEASE}}` branch off of `main` for the release candidate.
- Testing
    - [ ] Run `functional_tests.yml` workflow on `release/{{SPECIFIC_RELEASE}}`.
- [ ] Create a GitHub release of `release/{{SPECIFIC_RELEASE}}` with a `{{SPECIFIC_RELEASE}}` tag.
    - [ ] Copy the release notes from the ## Unreleased section of CHANGELOG.md.
- Git tag manipulation.
    - [ ] Create a git tag named `{{SPECIFIC_RELEASE}}` pointing to the `release/{{SPECIFIC_RELEASE}}` branch
    - [ ] {{REMOVE IF NOT MAJOR RELEASE}} Create a new git tag named `{{MAJOR_RELEASE}}`.
    - [ ] Move the `{{MAJOR_RELEASE}}` tag to point to `release/{{SPECIFIC_RELEASE}}`.
- [ ] Verify action with `uses: leanprover/lean-action@{{SPECIFIC_RELEASE}}` in test repo as a sanity check.
- Create a PR to: 
    - [ ] Create a PR to update CHANGELOG.md with the latest release.
    - [ ] {{REMOVE IF NOT MAJOR RELEASE}} Update instances of `leanprover/lean-action@{{MAJOR_SPECIFIC_RELEASE}}` in README.md.
- [ ] Post release announcement in `general/lean-action` Zulip topic.