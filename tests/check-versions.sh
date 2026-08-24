#!/usr/bin/env bash
# Version consistency checks:
#  1. PROGVERS (lib/core/common.sh) must match pkgver in packaging/arch/PKGBUILD
#     (the PKGBUILD builds from the tag tarball of the same version).
#  2. When building exactly at a git tag (CI sets TINKERGAME_CI_TAG, or HEAD
#     is a tagged commit locally), the tag must equal PROGVERS.
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail=0

PROGVERS="$(sed -n 's/^PROGVERS="\(.*\)"$/\1/p' lib/core/common.sh | head -1)"
if [ -z "$PROGVERS" ]; then
	printf '%s\n' "check-versions: PROGVERS not found in lib/core/common.sh" >&2
	exit 1
fi

PKGVER="$(sed -n "s/^pkgver=\(.*\)$/\1/p" packaging/arch/PKGBUILD | head -1)"
# Arch pkgver cannot contain dashes, so pre-release stages use dots there
# (0.1.0.alpha.1) while PROGVERS/git tags use dashes (v0.1.0-alpha.1)
PKGVER_TAG="v$PKGVER"
for stage in alpha beta rc; do
	PKGVER_TAG="${PKGVER_TAG//.$stage./-$stage.}"
done
if [ -n "$PKGVER" ] && [ "$PKGVER_TAG" != "$PROGVERS" ]; then
	printf '%s\n' "check-versions: packaging/arch/PKGBUILD pkgver ($PKGVER) does not match PROGVERS ($PROGVERS) - please bump pkgver" >&2
	fail=1
fi

TAG="${TINKERGAME_CI_TAG:-}"
if [ -z "$TAG" ] && command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	TAG="$(git tag --points-at HEAD 2>/dev/null | head -1)"
fi
if [ -n "$TAG" ] && [ "$TAG" != "$PROGVERS" ]; then
	printf '%s\n' "check-versions: git tag '$TAG' does not match PROGVERS '$PROGVERS'" >&2
	fail=1
fi

[ "$fail" -eq 0 ] && printf '%s\n' "check-versions: OK (PROGVERS=$PROGVERS)"
exit "$fail"
