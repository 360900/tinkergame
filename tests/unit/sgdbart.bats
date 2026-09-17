#!/usr/bin/env bash
# Unit tests for the SteamGridDB "file already exists" policy.
#
# downloadArtFromSteamGridDB runs without a local scope, so a per-call override
# must not be written back into the user's global SGDBHASFILE setting.

setup() {
	load helpers
	tg_load

	SGDBAPIKEY="testkey"
	STLPLAY=0
	checkSGDbApi() { return 0; }

	# Answer every SteamGridDB request with an empty (but successful) result set,
	# so the download loop has nothing to do and no files are touched.
	WGET="$BATS_TEST_TMPDIR/fakewget"
	printf '#!/bin/sh\nprintf "%%s" %s\n' "'{\"success\":true,\"data\":[]}'" >"$WGET"
	chmod +x "$WGET"
}

@test "downloadArtFromSteamGridDB: a per-call override does not overwrite the global SGDBHASFILE" {
	SGDBHASFILE="skip"
	downloadArtFromSteamGridDB "1234" "https://example.invalid/grids/game" "1234p" "" "" "" "" "" "" "replace" "1" >/dev/null
	[ "$SGDBHASFILE" = "skip" ]
}

@test "downloadArtFromSteamGridDB: the global setting survives repeated overridden calls" {
	SGDBHASFILE="backup"
	local i
	for i in 1 2 3; do
		downloadArtFromSteamGridDB "$i" "https://example.invalid/icons/game" "${i}_icon" "" "" "" "" "" "" "replace" "1" >/dev/null
	done
	[ "$SGDBHASFILE" = "backup" ]
}

@test "getSteamGridDBNonSteamIcon: falls back to the global SGDBHASFILE" {
	SGDBHASFILE="skip"
	# Report back which policy the icon download was asked to use
	downloadArtFromSteamGridDB() { printf '%s' "${10}"; }

	run getSteamGridDBNonSteamIcon "4242" "999"
	[ "$status" -eq 0 ]
	[ "$output" = "skip" ]
}

@test "getSteamGridDBNonSteamIcon: an explicit policy wins over the global setting" {
	SGDBHASFILE="skip"
	downloadArtFromSteamGridDB() { printf '%s' "${10}"; }

	run getSteamGridDBNonSteamIcon "4242" "999" "replace"
	[ "$status" -eq 0 ]
	[ "$output" = "replace" ]
}
