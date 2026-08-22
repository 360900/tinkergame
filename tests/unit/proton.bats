#!/usr/bin/env bash
# Unit tests for getProtonInternalName (compat tool name resolution).

setup() {
	load helpers
	tg_load
}

@test "getProtonInternalName: reads the '// Internal name' comment from compatibilitytool.vdf" {
	local tooldir="$BATS_TEST_TMPDIR/tools/GE-Proton9-20"
	mkdir -p "$tooldir"
	cp "$TG_FIXTURES/vdf/compatibilitytool.vdf" "$tooldir/"

	[ "$(getProtonInternalName "GE-Proton9-20;$tooldir/proton")" = "GE-Proton9-20" ]
}

@test "getProtonInternalName: TinkerGame's own tool resolves to Proton-tg" {
	local tooldir="$BATS_TEST_TMPDIR/tools/tinkergame"
	mkdir -p "$tooldir"
	sed 's/GE-Proton9-20/Proton-tg/' "$TG_FIXTURES/vdf/compatibilitytool.vdf" >"$tooldir/compatibilitytool.vdf"

	[ "$(getProtonInternalName "TinkerGame;$tooldir/tinkergame")" = "Proton-tg" ]
}

@test "getProtonInternalName: hardcodes Proton Experimental when no vdf exists" {
	local tooldir="$BATS_TEST_TMPDIR/tools/experimental"
	mkdir -p "$tooldir"

	[ "$(getProtonInternalName "experimental-9.0-20260801;$tooldir/proton")" = "proton_experimental" ]
}

@test "getProtonInternalName: hardcodes Proton Hotfix when no vdf exists" {
	local tooldir="$BATS_TEST_TMPDIR/tools/hotfix"
	mkdir -p "$tooldir"

	[ "$(getProtonInternalName "hotfix-9.0-20260801;$tooldir/proton")" = "proton_hotfix" ]
}

@test "getProtonInternalName: builds Valve Proton name from version (major only)" {
	local tooldir="$BATS_TEST_TMPDIR/tools/valve9"
	mkdir -p "$tooldir/files"  # Proton 9+ layout, no compatibilitytool.vdf

	[ "$(getProtonInternalName "9.0-2;$tooldir/proton")" = "proton_9" ]
}

@test "getProtonInternalName: builds Valve Proton name from version (major+minor)" {
	local tooldir="$BATS_TEST_TMPDIR/tools/valve411"
	mkdir -p "$tooldir/dist"  # legacy Proton layout

	[ "$(getProtonInternalName "4.11-12;$tooldir/proton")" = "proton_411" ]
}

@test "getProtonInternalName: falls back to the version string as internal name" {
	local tooldir="$BATS_TEST_TMPDIR/tools/boxtron"
	mkdir -p "$tooldir"  # no vdf, no dist/files -> not a Valve Proton

	[ "$(getProtonInternalName "Boxtron;$tooldir/run-dosbox")" = "Boxtron" ]
}
