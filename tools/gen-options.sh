#!/usr/bin/env bash
# tools/gen-options.sh -- generate lib/config/defaults.sh from data/options.def
#
# data/options.def is the single source of truth for config options.
# This generator emits the defaults function (setDefaultCfgValues) from the
# schema's default_expr column. Run it after editing data/options.def and
# commit the regenerated file together with the schema change.
#
# Usage:
#   tools/gen-options.sh            regenerate lib/config/defaults.sh in place
#   tools/gen-options.sh --check    verify the committed file is up to date
#                                   (exit 1 on drift; used by CI and smoke.sh)
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DEF="$ROOT/data/options.def"
OUTFILE="$ROOT/lib/config/defaults.sh"

if [ ! -f "$DEF" ]; then
	echo "gen-options: schema file not found: $DEF" >&2
	exit 1
fi

# ---- validation --------------------------------------------------------------
errors=0
scope_re='^(url|gui|global|default_template)$'
key_re='^[A-Z][A-Z0-9_]*$'
if awk -F '\t' -v scope_re="$scope_re" -v key_re="$key_re" '
	$0 ~ /^#/ || $0 ~ /^$/ { next }
	NF != 4 { printf "gen-options: wrong field count (%d): %s\n", NF, $0 > "/dev/stderr"; bad = 1; next }
	$1 !~ scope_re { printf "gen-options: bad scope: %s\n", $1 > "/dev/stderr"; bad = 1 }
	$2 !~ key_re { printf "gen-options: bad key: %s\n", $2 > "/dev/stderr"; bad = 1 }
	{ if (seen[$1 ":" $2]++) { printf "gen-options: duplicate key: %s/%s\n", $1, $2 > "/dev/stderr"; bad = 1 } }
	END { exit bad ? 1 : 0 }
' "$DEF"; then
	:
else
	errors=1
fi
[ "$errors" = 0 ] || exit 1

# ---- generation --------------------------------------------------------------
gen() {
	cat <<'HEADER'
#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.
#
# !! GENERATED FILE -- do not edit. Edit data/options.def and run tools/gen-options.sh.
#    CI enforces that this file matches the schema.

function setDefaultCfgValues {

HEADER
	awk -F '\t' '
	$0 ~ /^#/ || $0 ~ /^$/ { next }
	$3 == "" { next }                    # no default expression
	$1 == "gui" { next }                 # gui scope has no defaults function
	{
		if ($1 != scope) {
			if (scope != "") print "\t}"
			scope = $1
			printf "\n\tfunction setDefaultCfgValues%s {\n", $1
		}
		printf "\t\tif [ -z \"$%s\" ]; then\t\t%s=\"", $2, $2
		printf "%s", $3
		printf "\"; fi\n"
	}
	END { if (scope != "") print "\t}" }
	' "$DEF"
	cat <<'FOOTER'

	"${FUNCNAME[0]}$1"
}
FOOTER
}

if [ "${1:-}" = "--check" ]; then
	tmp="$(mktemp)"
	gen > "$tmp"
	if ! diff -u "$OUTFILE" "$tmp" >/dev/null; then
		echo "gen-options: lib/config/defaults.sh is out of date with data/options.def" >&2
		echo "gen-options: run: tools/gen-options.sh" >&2
		rm -f "$tmp"
		exit 1
	fi
	rm -f "$tmp"
	echo "gen-options: lib/config/defaults.sh is up to date"
else
	gen > "$OUTFILE"
	echo "gen-options: regenerated $OUTFILE"
fi
