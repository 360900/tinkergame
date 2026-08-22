#!/usr/bin/env bash
# Unit tests for AppID <-> hex AppID conversion and short-ID generation.

setup() {
	load helpers
	tg_load
}

@test "getAidFromHexAid: converts byte-swapped hex back to decimal AppID" {
	[ "$(getAidFromHexAid "3a02")" = "570" ]
	[ "$(getAidFromHexAid "ffffffff")" = "4294967295" ]
	[ "$(getAidFromHexAid "023a")" = "14850" ]
}

@test "getAidFromHexAid: stale REVAID from earlier calls does not leak in" {
	REVAID="stale"
	[ "$(getAidFromHexAid "3a02")" = "570" ]
}

@test "getHexAidForAid: byte-swaps and zero-pads odd-length hex" {
	# 570 = 0x23a -> chunks "02","3a" -> reversed "3a02"
	[ "$(getHexAidForAid 570)" = "3a02" ]
	# 4294967295 = 0xffffffff -> even length, unchanged order
	[ "$(getHexAidForAid 4294967295)" = "ffffffff" ]
}

@test "getHexAidForAid: round-trips through getAidFromHexAid" {
	for aid in 570 8930 2289830 4294967295 1; do
		run getHexAidForAid "$aid"
		[ "$status" -eq 0 ]
		[ "$(getAidFromHexAid "$output")" = "$aid" ]
	done
}

@test "getHexAidForAid: writes HEXAID meta config and consumes FUPDATE flag" {
	getHexAidForAid 570 >/dev/null
	[ -f "$GEMETA/570.conf" ]
	grep -q '^HEXAID="3a02"$' "$GEMETA/570.conf"
	# updateConfigEntry consumes the force-update flag after writing
	[ ! -f "$FUPDATE" ]
}

@test "getHexAidForAid: cached HEXAID from meta config is reused" {
	getHexAidForAid 570 >/dev/null
	# overwrite with a sentinel to prove the cache file is what gets read
	printf 'HEXAID="deadbeef"\n' >"$GEMETA/570.conf"
	unset HEXAID

	[ "$(getHexAidForAid 570)" = "deadbeef" ]
}

@test "getHexAidForAid: second arg suppresses output" {
	local out
	out="$(getHexAidForAid 570 X)"
	[ -z "$out" ]
}

@test "generateSteamShortID: wraps signed 32-bit to unsigned" {
	[ "$(generateSteamShortID 12345)" = "12345" ]
	[ "$(generateSteamShortID 0)" = "0" ]
	[ "$(generateSteamShortID -1)" = "4294967295" ]
	[ "$(generateSteamShortID 4294967301)" = "5" ]
}
