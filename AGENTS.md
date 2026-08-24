# TinkerGame contributor guide

## Writing style rules

- Never use the word "harness" anywhere: not in code, comments, commit messages, release notes, docs, or chat. Say "test suite", "test runner", or "test setup" instead.
- Never use em dashes ("—") anywhere. Use a comma, colon, or parentheses instead.
- These rules apply to project content (code, comments, docs, release notes) and to working diagrams, commit messages, GH release text, and assistant replies.

## Versioning

- `PROGVERS` in `lib/core/common.sh` follows `vMAJOR.MINOR.PATCH-stage.N` (SemVer with pre-release suffix). Alpha releases bump the `alpha.N` counter; larger feature batches bump MINOR and reset the counter.
- `packaging/arch/PKGBUILD` `pkgver` mirrors `PROGVERS` without the leading `v`, using dots instead of dashes in the pre-release stage (Arch forbids dashes), e.g. `v0.1.0-alpha.1` -> `0.1.0.alpha.1`. The `_tagver` variable in the PKGBUILD converts back to the dash form for the git tag tarball.
- `tests/check-versions.sh` (run in CI) verifies `PROGVERS`, `pkgver`, and the git tag stay in sync.
- Details for contributors: `CONTRIBUTING.md`, "Versioning" section.

## CI

- Workflow: `.github/workflows/ci.yml` (ShellCheck, bats unit tests, smoke/consistency checks, Arch package build).
- Local equivalents: `tests/run.sh unit|smoke|all`, `shellcheck --extended-analysis=false tinkergame uninstall.sh lib/*/*.sh tools/gen-options.sh`, `bash tools/gen-options.sh --check`.
- The Arch packaging job builds from a `git archive` tarball of HEAD with a `tinkergame-<tagver>/` prefix, placed inside `packaging/arch/` and referenced by plain filename (makepkg does not resolve parent-relative source paths).
