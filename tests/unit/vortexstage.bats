#!/usr/bin/env bash
# Picking the Vortex staging directory that belongs to the game's filesystem.
#
# Vortex hardlinks mods from its staging directory into the game, which only
# works on one filesystem, so setGameVortexStaging looks for the configured
# stage that sits on the same mount as the game.
#
# df is stubbed, because a test cannot arrange real mount points. The simulated
# ones are real directories inside the test tmpdir and the paths below them are
# genuinely below them, so a prefix match behaves here exactly as it would on a
# machine -- except for '/', which no test directory can sit directly under and
# which is the case that was broken.

setup() {
	load helpers
	tg_load

	STLVORTEXDIR="$BATS_TEST_TMPDIR/vortex"
	VORTEXSTAGELIST="$STLVORTEXDIR/stages.txt"
	mkdir -p "$STLVORTEXDIR"

	DISABLE_AUTOSTAGES=1   # stop after the lookup, so only the lookup is measured
	VTX="vortex"

	# Once a stage is found the function goes on to write a Vortex command. Point
	# that at the test dir: the default lives under /dev/shm, which exists on a
	# machine that has run TinkerGame and not on a fresh CI runner.
	export VORTSETCMD="$BATS_TEST_TMPDIR/vortset.cmd"
	: >"$VORTSETCMD"

	# Two simulated partitions, and paths that really do sit below them
	GAMESMP="$BATS_TEST_TMPDIR/mnt/games"
	SSDMP="$BATS_TEST_TMPDIR/mnt/ssd"
	GAMEDIR="$GAMESMP/SteamLibrary/steamapps/common/SkyrimVR"
	GAMESSTAGE="$GAMESMP/Vortex"
	SSDSTAGE="$SSDMP/Vortex"
	ROOTSTAGE="$BATS_TEST_TMPDIR/onroot"
	mkdir -p "$GAMEDIR" "$GAMESSTAGE" "$SSDSTAGE" "$ROOTSTAGE"

	TG_DFTABLE=""
	df() {
		local want="${*: -1}"
		local line
		printf 'Mounted on\n'
		while IFS= read -r line; do
			[ -z "$line" ] && continue
			case "$want" in
				"${line%%$'\t'*}"|"${line%%$'\t'*}"/*)
					printf '%s\n' "${line#*$'\t'}"
					return 0 ;;
			esac
		done <<< "$TG_DFTABLE"
		printf '%s\n' "/"
	}
}

# Each argument is "<mountpoint>|<reported mountpoint>"; anything at or below the
# first is reported as sitting on the second. Unlisted paths fall back to '/'.
tg_dfmap() {
	local entry
	TG_DFTABLE=""
	for entry in "$@"; do
		TG_DFTABLE+="${entry%%|*}"$'\t'"${entry#*|}"$'\n'
	done
}

# Both partitions behave as separate filesystems
tg_twoparts() { tg_dfmap "$GAMESMP|$GAMESMP" "$SSDMP|$SSDMP"; }

@test "setGameVortexStaging: a stage on the game's own partition is found" {
	tg_twoparts
	printf '%s\n' "$GAMESSTAGE" > "$VORTEXSTAGELIST"

	setGameVortexStaging "$GAMEDIR"
	[ "$VORTEXSTAGING" = "$GAMESSTAGE" ]
}

@test "setGameVortexStaging: a stage on another partition is skipped" {
	tg_twoparts
	printf '%s\n' "$SSDSTAGE" > "$VORTEXSTAGELIST"

	setGameVortexStaging "$GAMEDIR"
	[ -z "$VORTEXSTAGING" ]
}

@test "setGameVortexStaging: the right stage is picked out of several" {
	tg_twoparts
	printf '%s\n%s\n' "$SSDSTAGE" "$GAMESSTAGE" > "$VORTEXSTAGELIST"

	setGameVortexStaging "$GAMEDIR"
	[ "$VORTEXSTAGING" = "$GAMESSTAGE" ]
}

@test "setGameVortexStaging: a stage on the root filesystem is found when the game is there too" {
	# The case the prefix match could never hit: the pattern became '//'
	tg_dfmap
	printf '%s\n' "$ROOTSTAGE" > "$VORTEXSTAGELIST"

	setGameVortexStaging "$GAMEDIR"
	[ "$VORTEXSTAGING" = "$ROOTSTAGE" ]
}

@test "setGameVortexStaging: a stage on another partition is not used for a game on root" {
	# The mistake the obvious fix would make: '/' is a prefix of every path
	tg_dfmap "$SSDMP|$SSDMP"
	printf '%s\n' "$SSDSTAGE" > "$VORTEXSTAGELIST"

	setGameVortexStaging "$GAMEDIR"
	[ -z "$VORTEXSTAGING" ]
}

@test "setGameVortexStaging: the comment header is not treated as a path" {
	tg_twoparts
	{
		printf '%s\n' "# List of directories, which Vortex uses as 'Stage directories'"
		printf '%s\n' "# (see Wiki for a comprehensive description)"
		printf '%s\n' "$GAMESSTAGE"
	} > "$VORTEXSTAGELIST"

	setGameVortexStaging "$GAMEDIR"
	[ "$VORTEXSTAGING" = "$GAMESSTAGE" ]
}

@test "setGameVortexStaging: a path with spaces survives the lookup" {
	SPACEDSTAGE="$GAMESMP/my stage dir"
	mkdir -p "$SPACEDSTAGE"
	tg_twoparts
	printf '%s\n' "$SPACEDSTAGE" > "$VORTEXSTAGELIST"

	setGameVortexStaging "$GAMEDIR"
	[ "$VORTEXSTAGING" = "$SPACEDSTAGE" ]
}

@test "setGameVortexStaging: a listed directory that is gone is reported" {
	tg_twoparts
	printf '%s\n' "$GAMESMP/deleted-stage" > "$VORTEXSTAGELIST"

	LOGLEVEL=2   # that writelog call has no "E" flag, so it only reaches the log
	setGameVortexStaging "$GAMEDIR"
	grep -q "isn't a useable directory" "$TEMPLOG"
}

@test "setGameVortexStaging: a missing entry does not hide a usable one" {
	tg_twoparts
	printf '%s\n%s\n' "$GAMESMP/deleted-stage" "$GAMESSTAGE" > "$VORTEXSTAGELIST"

	setGameVortexStaging "$GAMEDIR"
	[ "$VORTEXSTAGING" = "$GAMESSTAGE" ]
}

@test "setGameVortexStaging: no stage list at all leaves the lookup empty" {
	tg_twoparts
	rm -f "$VORTEXSTAGELIST"

	setGameVortexStaging "$GAMEDIR"
	[ -z "$VORTEXSTAGING" ]
}

@test "setGameVortexStaging: a stale value from an earlier call is not reused" {
	# The function has no local scope, so leftovers would leak between games
	tg_twoparts
	printf '%s\n' "$GAMESSTAGE" > "$VORTEXSTAGELIST"
	setGameVortexStaging "$GAMEDIR"
	[ "$VORTEXSTAGING" = "$GAMESSTAGE" ]

	printf '%s\n' "$SSDSTAGE" > "$VORTEXSTAGELIST"
	setGameVortexStaging "$GAMEDIR"
	[ -z "$VORTEXSTAGING" ]
}
