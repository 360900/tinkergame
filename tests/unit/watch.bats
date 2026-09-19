#!/usr/bin/env bash
# Unit tests for the systemd user units that refresh Non-Steam artwork.
#
# The units are generated from the Steam userdata layout, so the interesting
# parts are which 'shortcuts.vdf' locations end up being watched and that
# install/uninstall drive systemctl with the right unit names.

setup() {
	load helpers
	tg_load

	# Two Steam accounts. TinkerGame itself only resolves the most recent one,
	# so a watcher built from that alone would miss the other account.
	SUSDA="$BATS_TEST_TMPDIR/steam/userdata"
	mkdir -p "$SUSDA/11111111/config" "$SUSDA/22222222/config"

	XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
	TG_UNITDIR="$XDG_CONFIG_HOME/systemd/user"

	# A real executable: unit generation refuses to write an ExecStart it cannot resolve
	mkdir -p "$BATS_TEST_TMPDIR/bin"
	TG_ENTRYPOINT="$BATS_TEST_TMPDIR/bin/tinkergame"
	: >"$TG_ENTRYPOINT"
	chmod +x "$TG_ENTRYPOINT"

	# Record the systemctl invocations instead of touching the real user manager
	TG_SCTLLOG="$BATS_TEST_TMPDIR/systemctl.calls"
	: >"$TG_SCTLLOG"
	SYSTEMCTL="$BATS_TEST_TMPDIR/fakesystemctl"
	{
		printf '#!/bin/sh\n'
		printf 'echo "$@" >> "%s"\n' "$TG_SCTLLOG"
	} >"$SYSTEMCTL"
	chmod +x "$SYSTEMCTL"
}

@test "tgWatchShortcutPaths: one shortcuts.vdf per Steam account" {
	run tgWatchShortcutPaths
	[ "$status" -eq 0 ]
	[ "$(printf '%s\n' "$output" | wc -l)" -eq 2 ]
	printf '%s\n' "$output" | grep -qx "$SUSDA/11111111/config/shortcuts.vdf"
	printf '%s\n' "$output" | grep -qx "$SUSDA/22222222/config/shortcuts.vdf"
}

@test "tgWatchShortcutPaths: a not yet existing shortcuts.vdf is still watched" {
	# Steam only writes the file once the first Non-Steam game is added -- watching
	# the path anyway is what makes the very first shortcut trigger a refresh
	[ ! -e "$SUSDA/11111111/config/shortcuts.vdf" ]
	run tgWatchShortcutPaths
	[ "$status" -eq 0 ]
	printf '%s\n' "$output" | grep -qx "$SUSDA/11111111/config/shortcuts.vdf"
}

@test "tgWatchShortcutPaths: fails when there is no Steam user directory" {
	SUSDA="$BATS_TEST_TMPDIR/nosuchsteam"
	run tgWatchShortcutPaths
	[ "$status" -ne 0 ]
	[ -z "$output" ]
}

@test "tgWatchWriteUnits: writes path, service and timer" {
	run tgWatchWriteUnits "$TG_UNITDIR"
	[ "$status" -eq 0 ]
	[ -f "$TG_UNITDIR/tinkergame-artwork.path" ]
	[ -f "$TG_UNITDIR/tinkergame-artwork.service" ]
	[ -f "$TG_UNITDIR/tinkergame-artwork.timer" ]
}

@test "tgWatchWriteUnits: the path unit watches every account" {
	tgWatchWriteUnits "$TG_UNITDIR"
	[ "$(grep -c '^PathChanged=' "$TG_UNITDIR/tinkergame-artwork.path")" -eq 2 ]
	grep -qx "PathChanged=$SUSDA/22222222/config/shortcuts.vdf" "$TG_UNITDIR/tinkergame-artwork.path"
}

@test "tgWatchWriteUnits: the service calls back into this installation" {
	tgWatchWriteUnits "$TG_UNITDIR"
	grep -qx "ExecStart=$TG_ENTRYPOINT -q update grid nonsteam" "$TG_UNITDIR/tinkergame-artwork.service"
	# oneshot is what debounces a burst of shortcut writes into a single refresh
	grep -qx "Type=oneshot" "$TG_UNITDIR/tinkergame-artwork.service"
}

@test "tgWatchWriteUnits: writes nothing when no Steam user directory exists" {
	SUSDA="$BATS_TEST_TMPDIR/nosuchsteam"
	run tgWatchWriteUnits "$TG_UNITDIR"
	[ "$status" -ne 0 ]
	[ ! -e "$TG_UNITDIR/tinkergame-artwork.path" ]
}

@test "tgWatchInstall: enables the path and the timer" {
	run tgWatchInstall
	[ "$status" -eq 0 ]
	grep -qxF -e "--user daemon-reload" "$TG_SCTLLOG"
	grep -qxF -e "--user enable --now tinkergame-artwork.path tinkergame-artwork.timer" "$TG_SCTLLOG"
}

@test "tgWatchInstall: keeps the units when systemctl is missing" {
	SYSTEMCTL="$BATS_TEST_TMPDIR/definitely-not-here"
	run tgWatchInstall
	[ "$status" -ne 0 ]
	# The generated units are still useful -- the user can enable them by hand
	[ -f "$TG_UNITDIR/tinkergame-artwork.path" ]
}

@test "tgWatchUninstall: disables and removes the units" {
	tgWatchWriteUnits "$TG_UNITDIR"
	run tgWatchUninstall
	[ "$status" -eq 0 ]
	grep -qxF -e "--user disable --now tinkergame-artwork.path tinkergame-artwork.timer" "$TG_SCTLLOG"
	[ ! -e "$TG_UNITDIR/tinkergame-artwork.path" ]
	[ ! -e "$TG_UNITDIR/tinkergame-artwork.service" ]
	[ ! -e "$TG_UNITDIR/tinkergame-artwork.timer" ]
}

@test "tgWatchUnitDir: honours XDG_CONFIG_HOME" {
	[ "$(tgWatchUnitDir)" = "$BATS_TEST_TMPDIR/config/systemd/user" ]
	XDG_CONFIG_HOME=""
	HOME="/home/tester"
	[ "$(tgWatchUnitDir)" = "/home/tester/.config/systemd/user" ]
}

@test "cli: 'artwork watch' routes install and uninstall" {
	local MARK="$BATS_TEST_TMPDIR/marks"
	mkdir -p "$MARK"
	howto() { touch "$MARK/howto"; }
	tgWatchInstall() { touch "$MARK/install"; }
	tgWatchUninstall() { touch "$MARK/uninstall"; }

	commandline artwork watch install
	[ -f "$MARK/install" ]

	commandline artwork watch uninstall
	[ -f "$MARK/uninstall" ]

	[ ! -f "$MARK/howto" ]
}

@test "cli: 'artwork watch' without a valid argument falls back to howto" {
	local MARK="$BATS_TEST_TMPDIR/marks"
	mkdir -p "$MARK"
	howto() { touch "$MARK/howto"; }
	tgWatchInstall() { touch "$MARK/install"; }

	commandline artwork watch enable
	[ -f "$MARK/howto" ]
	[ ! -f "$MARK/install" ]
}

@test "tgWatchWriteUnits: refuses to write when the executable cannot be resolved" {
	# An empty ExecStart is accepted by systemd and then fails on every single
	# trigger -- catching it here keeps that failure out of the journal
	TG_ENTRYPOINT=""
	run tgWatchWriteUnits "$TG_UNITDIR"
	[ "$status" -ne 0 ]
	[ ! -e "$TG_UNITDIR/tinkergame-artwork.service" ]
}

@test "tgWatchWriteUnits: refuses to write when the executable is gone" {
	rm -f "$TG_ENTRYPOINT"
	run tgWatchWriteUnits "$TG_UNITDIR"
	[ "$status" -ne 0 ]
	[ ! -e "$TG_UNITDIR/tinkergame-artwork.service" ]
}

@test "tgWatchWriteUnits: an undeliverable unit directory is an error, not a success" {
	# A regular file in place of a parent directory makes mkdir -p fail
	touch "$BATS_TEST_TMPDIR/blocker"
	run tgWatchWriteUnits "$BATS_TEST_TMPDIR/blocker/systemd/user"
	[ "$status" -ne 0 ]
}

@test "tgWatchInstall: does not enable anything when generation failed" {
	TG_ENTRYPOINT=""
	run tgWatchInstall
	[ "$status" -ne 0 ]
	# systemctl must not have been touched at all
	[ ! -s "$TG_SCTLLOG" ]
}
