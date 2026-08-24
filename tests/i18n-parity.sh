#!/usr/bin/env bash
# Check that every language file carries the same key set as english.txt.
# Keys are lines of the form KEY="..." (leading whitespace ignored).
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

fail=0
ref="lang/english.txt"
[ -f "$ref" ] || { printf '%s\n' "$ref: missing" >&2; exit 1; }

tmp_ref="$(mktemp)" || exit 1
tmp_cur="$(mktemp)" || exit 1
trap 'rm -f "$tmp_ref" "$tmp_cur"' EXIT

grep -oE '^[[:space:]]*[A-Za-z0-9_]+=' "$ref" | sed 's/^[[:space:]]*//; s/=$//' | sort -u > "$tmp_ref"

for f in lang/*.txt; do
	[ "$f" = "$ref" ] && continue
	grep -oE '^[[:space:]]*[A-Za-z0-9_]+=' "$f" | sed 's/^[[:space:]]*//; s/=$//' | sort -u > "$tmp_cur"
	if ! diff -q "$tmp_ref" "$tmp_cur" >/dev/null; then
		printf '%s\n' "$f: key set differs from english.txt:" >&2
		diff "$tmp_ref" "$tmp_cur" | sed 's/^/    /' >&2
		fail=1
	fi
done

if [ "$fail" -eq 0 ]; then
	printf '%s\n' "i18n parity: OK ($(find lang -maxdepth 1 -name '*.txt' | wc -l) files, $(grep -cE '^[[:space:]]*[A-Za-z0-9_]+=' "$ref") keys)"
fi
exit "$fail"
