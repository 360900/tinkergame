#!/usr/bin/env bash
# Unit tests for Steam compatibility-tool registration (CompatTool).

setup() {
	load helpers
	tg_load

	PROGCMD="tinkergame"
	ONSTEAMDECK=0
	SROOT="$BATS_TEST_TMPDIR/steam"
	STEAMCOMPATOOLS="$SROOT/compatibilitytools.d"
	mkdir -p "$SROOT"
}

@test "CompatTool add: registers the tool and reports success" {
	local tool="$BATS_TEST_TMPDIR/fake/bin/tinkergame"
	mkdir -p "${tool%/*}"
	printf '#!/bin/sh\nexit 0\n' >"$tool"
	chmod +x "$tool"
	ONSTEAMDECK=1

	run CompatTool add "$tool"
	[ "$status" -eq 0 ]
	[ -f "$STEAMCOMPATOOLS/TinkerGame/$CTVDF" ]
	[ -f "$STEAMCOMPATOOLS/TinkerGame/toolmanifest.vdf" ]
	[ "$(readlink "$STEAMCOMPATOOLS/TinkerGame/$PROGCMD")" = "$(realpath "$tool")" ]
	grep -q "Proton-tg" "$STEAMCOMPATOOLS/TinkerGame/$CTVDF"
}

@test "CompatTool add: updates an existing symlink and reports success" {
	local old="$BATS_TEST_TMPDIR/old/tinkergame"
	local new="$BATS_TEST_TMPDIR/new/tinkergame"
	mkdir -p "${old%/*}" "${new%/*}"
	printf '#!/bin/sh\nexit 0\n' >"$old"
	printf '#!/bin/sh\nexit 0\n' >"$new"
	chmod +x "$old" "$new"
	ONSTEAMDECK=1

	run CompatTool add "$old"
	[ "$status" -eq 0 ]

	run CompatTool add "$new"
	[ "$status" -eq 0 ]
	[ "$(readlink "$STEAMCOMPATOOLS/TinkerGame/$PROGCMD")" = "$(realpath "$new")" ]
}

@test "CompatTool add: fails when the Steam root is missing" {
	rm -rf "$SROOT"

	run CompatTool add
	[ "$status" -ne 0 ]
}

@test "CompatTool add: fails when compatibilitytools.d cannot be created" {
	local blocked="$BATS_TEST_TMPDIR/not-a-dir"
	printf 'file\n' >"$blocked"
	STEAMCOMPATOOLS="$blocked/compatibilitytools.d"

	run CompatTool add
	[ "$status" -ne 0 ]
}
