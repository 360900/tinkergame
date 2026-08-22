#!/usr/bin/env bash
# Run the TinkerGame test suite (bats unit tests + smoke checks).
#
# Usage:
#   tests/run.sh            # everything
#   tests/run.sh unit       # bats unit tests only
#   tests/run.sh smoke      # tests/smoke.sh only
#
# Environment:
#   BATS_ARGS  extra flags for bats (e.g. "--jobs 4", "-f vdf")

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BATS="$REPO_ROOT/tests/libs/bats/bin/bats"

cd "$REPO_ROOT"

run_unit() {
	if [ -n "${BATS_ARGS:-}" ]; then
		# shellcheck disable=SC2086  # intentional word splitting
		"$BATS" $BATS_ARGS tests/unit
	else
		"$BATS" tests/unit
	fi
}

run_smoke() {
	bash tests/smoke.sh
}

case "${1:-all}" in
	unit) run_unit ;;
	smoke) run_smoke ;;
	all)
		run_unit
		run_smoke
		;;
	*)
		echo "usage: $0 [unit|smoke|all]" >&2
		exit 2
		;;
esac
