#!/usr/bin/env bash
# Unit tests for the stored "which SteamGridDB game is this" decisions.
#
# The point of the store is that the user is asked once per entry and never
# again -- including for entries that have no artwork anywhere, which are kept
# as a decision with an empty value rather than as a repeated failure.

setup() {
	load helpers
	tg_load

	STLCFGDIR="$BATS_TEST_TMPDIR/cfg"
	STLSGDBNAMESCFG="$STLCFGDIR/sgdbnames.conf"
	mkdir -p "$STLCFGDIR"

	SGDBAPIKEY="testkey"
	checkSGDbApi() { return 0; }

	# the notification text comes from the real language file, as in production
	# shellcheck source=/dev/null
	source "$TG_ROOT/lang/english.txt"
}

@test "tgSgdbDecision: an undecided entry is reported as undecided" {
	run tgSgdbDecision "Eden"
	[ "$status" -ne 0 ]
}

@test "tgSgdbDecision: a stored game ID comes back" {
	tgSgdbSetDecision "Eden" "9981"
	run tgSgdbDecision "Eden"
	[ "$status" -eq 0 ]
	[ "$output" = "9981" ]
}

@test "tgSgdbDecision: 'never' is a decision, not a missing one" {
	# This is what stops an entry without artwork from being asked about forever
	tgSgdbSetDecision "Caustic" ""
	run tgSgdbDecision "Caustic"
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

@test "tgSgdbDecision: entry names are matched literally, not as a regex" {
	tgSgdbSetDecision "S.T.A.L.K.E.R." "42"
	run tgSgdbDecision "SXTXAXLXKXEXRX"
	[ "$status" -ne 0 ]
}

@test "tgSgdbDecision: a name that is a prefix of another does not borrow its decision" {
	tgSgdbSetDecision "Half-Life 2" "77"
	run tgSgdbDecision "Half-Life"
	[ "$status" -ne 0 ]
}

@test "tgSgdbSetDecision: re-deciding replaces instead of appending" {
	tgSgdbSetDecision "Eden" "1111"
	tgSgdbSetDecision "Eden" "9981"
	[ "$(grep -c "^Eden=" "$STLSGDBNAMESCFG")" -eq 1 ]
	run tgSgdbDecision "Eden"
	[ "$output" = "9981" ]
}

@test "tgSgdbSetDecision: other entries survive a rewrite" {
	tgSgdbSetDecision "Eden" "1"
	tgSgdbSetDecision "Caustic" ""
	tgSgdbSetDecision "Eden" "2"
	run tgSgdbDecision "Caustic"
	[ "$status" -eq 0 ]
}

@test "tgSgdbSetDecision: the file explains itself" {
	tgSgdbSetDecision "Eden" "1"
	grep -q "^#" "$STLSGDBNAMESCFG"
}

@test "tgSgdbSetDecision: refuses an empty entry name" {
	run tgSgdbSetDecision "" "123"
	[ "$status" -ne 0 ]
}

@test "tgSgdbCandidates: keeps the whole ranked list, not just the first hit" {
	WGET="$BATS_TEST_TMPDIR/fakewget"
	{
		printf '#!/bin/sh\n'
		printf '%s\n' 'printf "%s" "{\"success\":true,\"data\":[{\"id\":10,\"name\":\"Eden\"},{\"id\":20,\"name\":\"Eden Emulator\"}]}"'
	} >"$WGET"
	chmod +x "$WGET"

	run tgSgdbCandidates "Eden"
	[ "$status" -eq 0 ]
	[ "$(printf '%s\n' "$output" | wc -l)" -eq 2 ]
	printf '%s\n' "$output" | grep -q "20.*Eden Emulator"
}

@test "tgSgdbCandidates: an unsuccessful response is an error, not an empty list" {
	WGET="$BATS_TEST_TMPDIR/fakewget"
	{
		printf '#!/bin/sh\n'
		printf '%s\n' 'printf "%s" "{\"success\":false}"'
	} >"$WGET"
	chmod +x "$WGET"

	run tgSgdbCandidates "Eden"
	[ "$status" -ne 0 ]
}

@test "tgSgdbPrompt: picking a number stores that game ID" {
	tgSgdbCandidates() { printf '10\tEden\n20\tEden Emulator\n'; }
	run tgSgdbPrompt "Eden" <<< "2"
	[ "$status" -eq 0 ]
	run tgSgdbDecision "Eden"
	[ "$output" = "20" ]
}

@test "tgSgdbPrompt: 'x' stores the never-look-up decision" {
	tgSgdbCandidates() { printf ''; }
	run tgSgdbPrompt "Caustic" <<< "x"
	[ "$status" -eq 0 ]
	run tgSgdbDecision "Caustic"
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

@test "tgSgdbPrompt: 's' leaves the entry undecided so it comes back" {
	tgSgdbCandidates() { printf '10\tEden\n'; }
	run tgSgdbPrompt "Eden" <<< "s"
	[ "$status" -eq 1 ]
	run tgSgdbDecision "Eden"
	[ "$status" -ne 0 ]
}

@test "tgSgdbPrompt: 'q' asks for the whole run to stop" {
	tgSgdbCandidates() { printf '10\tEden\n'; }
	run tgSgdbPrompt "Eden" <<< "q"
	[ "$status" -eq 2 ]
}

@test "tgSgdbPrompt: an out of range number decides nothing" {
	tgSgdbCandidates() { printf '10\tEden\n'; }
	run tgSgdbPrompt "Eden" <<< "9"
	[ "$status" -eq 1 ]
	run tgSgdbDecision "Eden"
	[ "$status" -ne 0 ]
}

@test "tgSgdbPrompt: garbage input decides nothing" {
	tgSgdbCandidates() { printf '10\tEden\n'; }
	run tgSgdbPrompt "Eden" <<< "ja bitte"
	[ "$status" -eq 1 ]
	run tgSgdbDecision "Eden"
	[ "$status" -ne 0 ]
}

@test "tgSgdbPrompt: 't' searches again under a different term" {
	# The whole reason overrides existed: the shortcut name is not the store name
	tgSgdbCandidates() {
		if [ "$1" = "Eden Emulator" ]; then printf '20\tEden Emulator\n'; else printf '10\tEden\n'; fi
	}
	run tgSgdbPrompt "Eden" < <(printf 't\nEden Emulator\n1\n')
	[ "$status" -eq 0 ]
	run tgSgdbDecision "Eden"
	[ "$output" = "20" ]
}

@test "tgSgdbUndecidedEntries: lists only what has not been decided" {
	haveAnySteamShortcuts() { return 0; }
	getSteamShortcutHex() { printf 'a\nb\nc\n'; }
	parseSteamShortcutEntryAppName() {
		case "$1" in a) printf 'Eden' ;; b) printf 'Caustic' ;; c) printf 'Celeste' ;; esac
	}
	tgSgdbSetDecision "Caustic" ""
	tgSgdbSetDecision "Celeste" "5"

	run tgSgdbUndecidedEntries
	[ "$output" = "Eden" ]
}

@test "tgSgdbResolve: reports nothing to do when everything is decided" {
	tgSgdbUndecidedEntries() { printf ''; }
	run tgSgdbResolve
	[ "$status" -eq 0 ]
	printf '%s\n' "$output" | grep -qi "nothing to do"
}

@test "tgSgdbResolve: a named entry is re-decided even though it was settled" {
	tgSgdbSetDecision "Eden" "10"
	tgSgdbCandidates() { printf '20\tEden Emulator\n'; }
	run tgSgdbResolve "Eden" <<< "1"
	[ "$status" -eq 0 ]
	run tgSgdbDecision "Eden"
	[ "$output" = "20" ]
}

@test "tgSgdbResolve: quitting leaves the remaining entries on the list" {
	tgSgdbUndecidedEntries() { printf 'Eden\nCaustic\n'; }
	tgSgdbCandidates() { printf '10\tEden\n'; }
	run tgSgdbResolve <<< "q"
	[ "$status" -eq 0 ]
	run tgSgdbDecision "Caustic"
	[ "$status" -ne 0 ]
}

@test "cli: 'artwork resolve' routes through, with and without a name" {
	local MARK="$BATS_TEST_TMPDIR/marks"
	mkdir -p "$MARK"
	howto() { touch "$MARK/howto"; }
	tgSgdbResolve() { printf '%s' "${1:-ALL}" > "$MARK/arg"; }

	commandline artwork resolve
	[ "$(cat "$MARK/arg")" = "ALL" ]

	commandline artwork resolve "Eden"
	[ "$(cat "$MARK/arg")" = "Eden" ]

	[ ! -f "$MARK/howto" ]
}

@test "tgSgdbNotifyUndecided: a non-interactive run offers to open the resolver" {
	# bats captures stdout, so this is the systemd case: no terminal to print to
	NOTY="$BATS_TEST_TMPDIR/fakenoty"
	printf '#!/bin/sh\nprintf "%%s\\n" "$@" > "%s/noty.call"\nprintf ""\n' "$BATS_TEST_TMPDIR" > "$NOTY"
	chmod +x "$NOTY"
	USENOTIFIER=1
	NOTYARGS="-a TinkerGame"

	tgSgdbNotifyUndecided "3"

	local waited=0
	while [ ! -e "$BATS_TEST_TMPDIR/noty.call" ] && [ "$waited" -lt 50 ]; do
		sleep 0.1
		waited=$(( waited + 1 ))
	done

	[ -e "$BATS_TEST_TMPDIR/noty.call" ]
	grep -q -- "-A" "$BATS_TEST_TMPDIR/noty.call"
	grep -q "3" "$BATS_TEST_TMPDIR/noty.call"
}

@test "tgSgdbNotifyUndecided: acting on the notification opens the resolver" {
	NOTY="$BATS_TEST_TMPDIR/fakenoty"
	# notify-send prints the chosen action name on stdout
	printf '#!/bin/sh\nprintf "resolve"\n' > "$NOTY"
	chmod +x "$NOTY"
	USENOTIFIER=1
	NOTYARGS="-a TinkerGame"

	USETERM="$BATS_TEST_TMPDIR/faketerm"
	printf '#!/bin/sh\necho "$@" > "%s/term.call"\n' "$BATS_TEST_TMPDIR" > "$USETERM"
	chmod +x "$USETERM"
	TERMARGS="-e"
	TG_ENTRYPOINT="$BATS_TEST_TMPDIR/tinkergame"
	: > "$TG_ENTRYPOINT"
	chmod +x "$TG_ENTRYPOINT"

	tgSgdbNotifyUndecided "2"

	local waited=0
	while [ ! -e "$BATS_TEST_TMPDIR/term.call" ] && [ "$waited" -lt 50 ]; do
		sleep 0.1
		waited=$(( waited + 1 ))
	done

	[ -e "$BATS_TEST_TMPDIR/term.call" ]
	grep -q "artwork resolve" "$BATS_TEST_TMPDIR/term.call"
}

@test "tgSgdbNotifyUndecided: nothing to decide means no notification" {
	NOTY="$BATS_TEST_TMPDIR/fakenoty"
	printf '#!/bin/sh\necho fired >> "%s/noty.calls"\n' "$BATS_TEST_TMPDIR" > "$NOTY"
	chmod +x "$NOTY"
	USENOTIFIER=1

	tgSgdbNotifyUndecided "0"
	[ ! -e "$BATS_TEST_TMPDIR/noty.calls" ]
}

@test "tgSgdbNotifyUndecided: a disabled notifier is not an error" {
	USENOTIFIER=0
	run tgSgdbNotifyUndecided "3"
	[ "$status" -eq 0 ]
}

@test "tgSgdbResolveTerminal: refuses when no terminal is configured" {
	USETERM=""
	run tgSgdbResolveTerminal
	[ "$status" -ne 0 ]
}

@test "tgSgdbResolveTerminal: refuses when the executable cannot be resolved" {
	USETERM="$BATS_TEST_TMPDIR/faketerm"
	printf '#!/bin/sh\nexit 0\n' > "$USETERM"
	chmod +x "$USETERM"
	TG_ENTRYPOINT=""
	run tgSgdbResolveTerminal
	[ "$status" -ne 0 ]
}

@test "tgSgdbResolveTerminal: launches the resolver in the configured terminal" {
	USETERM="$BATS_TEST_TMPDIR/faketerm"
	printf '#!/bin/sh\necho "$@" > "%s/term.call"\n' "$BATS_TEST_TMPDIR" > "$USETERM"
	chmod +x "$USETERM"
	TERMARGS="-e"
	TG_ENTRYPOINT="$BATS_TEST_TMPDIR/tinkergame"
	: > "$TG_ENTRYPOINT"
	chmod +x "$TG_ENTRYPOINT"

	run tgSgdbResolveTerminal
	[ "$status" -eq 0 ]
	grep -q -- "-e" "$BATS_TEST_TMPDIR/term.call"
	grep -q "artwork resolve" "$BATS_TEST_TMPDIR/term.call"
}
