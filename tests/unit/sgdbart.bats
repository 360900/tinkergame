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
	# Each call is recorded, so tests can assert that no request was made at all.
	TG_WGETLOG="$BATS_TEST_TMPDIR/wget.calls"
	: >"$TG_WGETLOG"
	WGET="$BATS_TEST_TMPDIR/fakewget"
	{
		printf '#!/bin/sh\n'
		printf 'echo "$@" >> "%s"\n' "$TG_WGETLOG"
		printf '%s\n' 'printf "%s" "{\"success\":true,\"data\":[]}"'
	} >"$WGET"
	chmod +x "$WGET"

	# Artwork lands in the download cache dir, not in a real Steam grid folder
	SGDBDLTOSTEAM=0
	STLDLDIR="$BATS_TEST_TMPDIR/dl"
	mkdir -p "$STLDLDIR/steamgriddb"

	# A non-empty SUSDA keeps setSteamPaths from running and touching the real
	# /dev/shm; SUIC is where the "apply to Steam" path writes to.
	SUSDA="$BATS_TEST_TMPDIR/steam"
	SUIC="$BATS_TEST_TMPDIR/steam/userdata/1/config"
	mkdir -p "$SUIC/grid"
}

tg_requests() { grep -c . "$TG_WGETLOG"; }

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

@test "downloadArtFromSteamGridDB: existing artwork is not requested again" {
	touch "$STLDLDIR/steamgriddb/1234_hero.png"
	downloadArtFromSteamGridDB "1234" "https://example.invalid/heroes/game" "1234_hero" "" "" "" "" "" "" "skip" "0" >/dev/null
	[ "$(tg_requests)" -eq 0 ]
}

@test "downloadArtFromSteamGridDB: each artwork type is checked on its own" {
	# Boxart is present, the logo for the same game is not -- the logo must still be fetched
	touch "$STLDLDIR/steamgriddb/1234p.png"
	downloadArtFromSteamGridDB "1234" "https://example.invalid/logos/game" "1234_logo" "" "" "" "" "" "" "skip" "0" >/dev/null
	[ "$(tg_requests)" -eq 1 ]
}

@test "downloadArtFromSteamGridDB: a longer AppID's files do not count as ours" {
	# "1234p.png" belongs to AppID 1234, not to 123 -- the '.' in the glob anchors this
	touch "$STLDLDIR/steamgriddb/1234p.png"
	downloadArtFromSteamGridDB "123" "https://example.invalid/grids/game" "123p" "" "" "" "" "" "" "skip" "0" >/dev/null
	[ "$(tg_requests)" -eq 1 ]
}

@test "downloadArtFromSteamGridDB: 'replace' still re-requests existing artwork" {
	touch "$STLDLDIR/steamgriddb/1234_hero.png"
	downloadArtFromSteamGridDB "1234" "https://example.invalid/heroes/game" "1234_hero" "" "" "" "" "" "" "replace" "0" >/dev/null
	[ "$(tg_requests)" -eq 1 ]
}

@test "downloadArtFromSteamGridDB: a batched request is never skipped" {
	# For Steam batches SGDBFILENAME holds a newline separated list, which must not be globbed
	touch "$STLDLDIR/steamgriddb/1234.png"
	downloadArtFromSteamGridDB "1234
5678" "https://example.invalid/grids/game" "1234
5678" "" "" "" "" "" "" "skip" "0" >/dev/null
	[ "$(tg_requests)" -eq 1 ]
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
