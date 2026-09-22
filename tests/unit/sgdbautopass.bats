#!/usr/bin/env bash
# The automatic artwork pass, as run by the systemd watcher.
#
# Matching by name is a guess. A wrong guess produces artwork that looks
# correct and that nothing reports, which is harder to undo than a blank entry
# is to fill. Nobody reviews an automatic run, so it never makes that call:
# entries without a stored match are left alone and reported instead.
# 'update grid nonsteam' keeps guessing exactly as it always has.

setup() {
	load helpers
	tg_load

	STLCFGDIR="$BATS_TEST_TMPDIR/cfg"
	STLSGDBNAMESCFG="$STLCFGDIR/sgdbnames.conf"
	mkdir -p "$STLCFGDIR"

	SGDBAPIKEY="testkey"
	checkSGDbApi() { return 0; }

	STUIDPATH="$BATS_TEST_TMPDIR/user"
	mkdir -p "$STUIDPATH/config/grid"
	SCVDF="shortcuts.vdf"
	: > "$STUIDPATH/config/$SCVDF"

	haveAnySteamShortcuts() { return 0; }
	getSteamShortcutHex() { printf 'a\nb\n'; }
	parseSteamShortcutEntryAppName() {
		case "$1" in a) printf 'Eden' ;; b) printf 'Caustic' ;; esac
	}
	parseSteamShortcutEntryAppID() {
		case "$1" in a) printf '111' ;; b) printf '222' ;; esac
	}

	# Record which entries the artwork fetch was asked for
	TG_FETCHLOG="$BATS_TEST_TMPDIR/fetch.calls"
	: >"$TG_FETCHLOG"
	# The real function leaves the resolved SteamGridDB ID in this file for the
	# icon step that follows, so the stub has to provide it too
	NOSTSGDBIDSHMFILE="$BATS_TEST_TMPDIR/nostsgdbid.txt"
	: > "$NOSTSGDBIDSHMFILE"
	commandlineGetSteamGridDBArtwork() { echo "$*" >> "$TG_FETCHLOG"; printf '0' > "$NOSTSGDBIDSHMFILE"; }
	getSteamGridDBNonSteamIcon() { :; }
	findNonSteamGameIcon() { printf ''; }
	editSteamShortcutEntry() { :; }
	tgSgdbNotifyUndecided() { printf '%s' "$1" > "$BATS_TEST_TMPDIR/notified"; }
}

@test "getGridsForNonSteamGames: 'update grid nonsteam' still matches undecided entries by name" {
	getGridsForNonSteamGames >/dev/null
	grep -q -- "--search-name=Eden" "$TG_FETCHLOG"
	grep -q -- "--search-name=Caustic" "$TG_FETCHLOG"
}

@test "getGridsForNonSteamGames: the automatic pass leaves undecided entries alone" {
	getGridsForNonSteamGames "ask" >/dev/null
	[ ! -s "$TG_FETCHLOG" ]
}

@test "getGridsForNonSteamGames: the automatic pass still fetches a decided entry" {
	tgSgdbSetDecision "Eden" "9981"
	getGridsForNonSteamGames "ask" >/dev/null
	grep -q -- "--search-id=9981" "$TG_FETCHLOG"
	# the undecided one is still left alone
	grep -qv "Caustic" "$TG_FETCHLOG"
}

@test "getGridsForNonSteamGames: 'never' stays skipped in the automatic pass" {
	tgSgdbSetDecision "Caustic" ""
	getGridsForNonSteamGames "ask" >/dev/null
	[ ! -s "$TG_FETCHLOG" ]
}

@test "getGridsForNonSteamGames: entries left alone are reported for the notification" {
	getGridsForNonSteamGames "ask" >/dev/null
	[ -e "$BATS_TEST_TMPDIR/notified" ]
	[ "$(cat "$BATS_TEST_TMPDIR/notified")" = "2" ]
}

@test "getGridsForNonSteamGames: nothing left to decide means no notification" {
	tgSgdbSetDecision "Eden" ""
	tgSgdbSetDecision "Caustic" ""
	getGridsForNonSteamGames "ask" >/dev/null
	[ ! -e "$BATS_TEST_TMPDIR/notified" ]
}

@test "getGridsForNonSteamGames: the automatic pass puts artwork where Steam looks" {
	# SGDBDLTOSTEAM defaults to 0, which parks artwork in the download cache.
	# An automatic pass that leaves it there has done nothing a user can see.
	tgSgdbSetDecision "Eden" "9981"
	getGridsForNonSteamGames "ask" >/dev/null
	grep -q -- "--apply" "$TG_FETCHLOG"
}

@test "getGridsForNonSteamGames: 'update grid nonsteam' keeps honouring SGDBDLTOSTEAM" {
	tgSgdbSetDecision "Eden" "9981"
	getGridsForNonSteamGames >/dev/null
	grep -qv -- "--apply" "$TG_FETCHLOG"
}

@test "getGridsForNonSteamGames: a complete entry is not reported as needing a match" {
	# Saying "leaving this for you" about entries that need nothing buries the ones that do
	tgSgdbArtworkMissing() { return 0; }
	run getGridsForNonSteamGames "ask"
	printf '%s\n' "$output" | grep -qv "Leaving"
}

@test "getGridsForNonSteamGames: an incomplete entry is reported" {
	tgSgdbArtworkMissing() { printf 'hero\n'; }
	run getGridsForNonSteamGames "ask"
	printf '%s\n' "$output" | grep -q "Leaving 'Eden ("
}
