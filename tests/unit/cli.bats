#!/usr/bin/env bash
# CLI command registry and dispatch tests (lib/cli/registry.sh + dispatch.sh)
# for the grouped verb tree introduced in Phase 4.

load helpers

setup() {
	tg_load
	MARK="$BATS_TEST_TMPDIR/markers"
	mkdir -p "$MARK"

	# ---- function overrides (markers) ----
	howto() { touch "$MARK/howto"; }
	GameFilesMenu() { touch "$MARK/GameFilesMenu"; }
	FUSEID() { touch "$MARK/FUSEID"; echo "$1"; }
	EditorDialog() { touch "$MARK/EditorDialog"; }
	reCreateCompatdata() { touch "$MARK/reCreateCompatdata"; echo "$1"; }
	prettyPrintProtonArr() { touch "$MARK/prettyPrintProtonArr"; }
	dlCustomProtonGate() { touch "$MARK/dlCustomProtonGate"; echo "$1"; }
	setYadBin() { touch "$MARK/setYadBin"; }
	listSteamGames() { touch "$MARK/listSteamGames"; echo "$1"; }
	notiShow() { :; }

	# vars referenced by the dispatch bodies under test
	export XDGO="echo"
	export PROGCMD="tinkergame"
}

@test "cli: registry loaded eagerly with all groups" {
	[ "$TG_CMD_REGISTRY_LOADED" = "1" ]
	[ "$(tgCmdGroups | wc -l)" -eq 11 ]
}

@test "cli: General group has 22 verbs and starts with help" {
	[ "$(tgCmdGroupVerbs General | wc -l)" -eq 22 ]
	[ "$(tgCmdGroupVerbs General | head -n1)" = "help" ]
}

@test "cli: game group verbs in registry order" {
	run tgCmdGroupVerbs game
	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "files" ]
	[ "${lines[14]}" = "launcher" ]
}

@test "cli: tgCmdHas positive and negative" {
	tgCmdHas game files
	tgCmdHas General version
	run tgCmdHas game bogus
	[ "$status" -ne 0 ]
}

@test "cli: dispatch routes 'game files' through FUSEID to GameFilesMenu" {
	run commandline game files 12345
	[ "$status" -eq 0 ]
	[ -f "$MARK/GameFilesMenu" ]
	[ -f "$MARK/FUSEID" ]
	[ ! -f "$MARK/howto" ]
}

@test "cli: dispatch unknown sub-verb falls back to howto" {
	run commandline game bogus
	[ "$status" -eq 0 ]
	[ -f "$MARK/howto" ]
	[ ! -f "$MARK/GameFilesMenu" ]
}

@test "cli: unknown top-level verb falls back to howto" {
	run commandline frobnicate
	[ "$status" -eq 0 ]
	[ -f "$MARK/howto" ]
}

@test "cli: Steam internal 'run' falls through silently" {
	run commandline waitforexitandrun /some/game.exe
	[ "$status" -eq 0 ]
	[ ! -f "$MARK/howto" ]
}

@test "cli: lang= falls through silently" {
	run commandline lang=german
	[ "$status" -eq 0 ]
	[ ! -f "$MARK/howto" ]
}

@test "cli: version prints program version" {
	run commandline version
	[ "$status" -eq 0 ]
	[[ "$output" == *"tinkergame-"* ]]
	[ ! -f "$MARK/howto" ]
}

@test "cli: help routes to howto" {
	run commandline --help
	[ "$status" -eq 0 ]
	[ -f "$MARK/howto" ]
}

@test "cli: editor routes through FUSEID to EditorDialog" {
	run commandline editor 12345
	[ "$status" -eq 0 ]
	[ -f "$MARK/EditorDialog" ]
}

@test "cli: game compatdata keeps the legacy reCreateCompatdata mode arg" {
	run commandline game compatdata 12345 s
	[ "$status" -eq 0 ]
	[ -f "$MARK/reCreateCompatdata" ]
	[[ "$output" == *"createcompatdata"* ]]
}

@test "cli: proton download routes to dlCustomProtonGate" {
	run commandline proton download latestge
	[ "$status" -eq 0 ]
	[ -f "$MARK/dlCustomProtonGate" ]
}

@test "cli: proton list displays via prettyPrintProtonArr" {
	run commandline proton list
	[ "$status" -eq 0 ]
	[ -f "$MARK/prettyPrintProtonArr" ]
}

@test "cli: list routes to listSteamGames" {
	run commandline list installed
	[ "$status" -eq 0 ]
	[ -f "$MARK/listSteamGames" ]
}

@test "cli: config yad routes to setYadBin" {
	run commandline config yad someyad
	[ "$status" -eq 0 ]
	[ -f "$MARK/setYadBin" ]
}

@test "cli: -q sets quiet and recurses without howto" {
	QUIETDUMP="$BATS_TEST_TMPDIR/quietdump"
	(
		set +e
		commandline -q version
		printf 'STLQUIET=%s\nUSENOTIFIER=%s\n' "${STLQUIET:-}" "${USENOTIFIER:-}"
	) >"$QUIETDUMP" 2>/dev/null
	grep -q 'STLQUIET=1' "$QUIETDUMP"
	grep -q 'USENOTIFIER=0' "$QUIETDUMP"
	grep -q 'tinkergame-' "$QUIETDUMP"
	[ ! -f "$MARK/howto" ]
}
