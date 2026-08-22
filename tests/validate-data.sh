#!/usr/bin/env bash
# Validate the semi-colon-separated quoted-field data files in misc/.
#
# Every non-empty line must consist of a fixed number of double-quoted fields
# separated by single ';'. The AppID field must be numeric (31337 is the
# documented placeholder AppID). (key, AppID) pairs must be unique.
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail=0

# validate_db <file> <min-fields> <max-fields> <appid-field-index (1-based, empty to skip)> <label>
validate_db() {
	local file="$1" minfields="$2" maxfields="$3" aididx="$4" label="$5"
	local line lineno field appid key
	local -a fields
	local errors=0
	[ -f "$file" ] || { printf '%s\n' "$file: missing" >&2; fail=1; return; }
	lineno=0
	while IFS= read -r line; do
		lineno=$((lineno + 1))
		[ -z "$line" ] && continue
		case "$line" in '#'*) continue ;; esac

		IFS=';' read -r -a fields <<< "$line"
		if [ "${#fields[@]}" -lt "$minfields" ] || [ "${#fields[@]}" -gt "$maxfields" ]; then
			printf '%s\n' "$file:$lineno: expected $minfields-$maxfields fields, found ${#fields[@]}: $line" >&2
			fail=1; errors=1
			continue
		fi

		local fieldbad=0
		for field in "${fields[@]}"; do
			if ! printf '%s\n' "$field" | grep -qE '^"[^"]*"$'; then
				printf '%s\n' "$file:$lineno: malformed field '$field' (unbalanced quotes): $line" >&2
				fail=1; errors=1; fieldbad=1
			fi
		done
		[ "$fieldbad" -eq 1 ] && continue

		if [ -n "$aididx" ]; then
			# AppID must be numeric (31337 = placeholder)
			appid="${fields[$((aididx - 1))]%\"}"
			appid="${appid#\"}"
			if ! printf '%s\n' "$appid" | grep -qE '^[0-9]+$'; then
				printf '%s\n' "$file:$lineno: AppID '$appid' is not numeric: $line" >&2
				fail=1; errors=1
			fi
		fi

		# unique (key, AppID) pairs
		key="${fields[0]%\"}"; key="${key#\"}"
		if [ -n "$aididx" ]; then
			appid="${fields[$((aididx - 1))]%\"}"; appid="${appid#\"}"
			if grep -qxF "$(printf '%s;%s' "$key" "$appid")" "$file.dup" 2>/dev/null; then
				printf '%s\n' "$file:$lineno: duplicate (key, AppID) pair: $key / $appid" >&2
				fail=1; errors=1
			else
				printf '%s;%s\n' "$key" "$appid" >> "$file.dup"
			fi
		else
			if grep -qxF "$key" "$file.dup" 2>/dev/null; then
				printf '%s\n' "$file:$lineno: duplicate key: $key" >&2
				fail=1; errors=1
			else
				printf '%s\n' "$key" >> "$file.dup"
			fi
		fi
	done < "$file"
	rm -f "$file.dup"
	if [ "$errors" -eq 0 ]; then
		printf '%s\n' "$label: OK ($lineno lines)"
	fi
}

validate_db "misc/vortexgames.txt" 3 3 3 "vortexgames"
validate_db "misc/mo2games.txt" 4 4 2 "mo2games"
validate_db "misc/hmmgames.txt" 4 4 2 "hmmgames"
validate_db "misc/steamworks-shared.txt" 3 4 "" "steamworks-shared"

[ "$fail" -eq 0 ] || exit 1
