#!/usr/bin/env bash
# Regression tests for the downloadable custom Proton list.
#
# The asset filter is a regex and used to say '7.x' unescaped, which also
# matched the dash in GE-Proton11-7-x86_64.tar.gz and silently dropped every
# x86_64 build of any release whose number contains 7 (issue #7).
#
# The GitHub API returns assets alphabetically, so 'aarch64' sorts before
# 'x86_64'. The list must be filtered to the host architecture, otherwise
# 'latest' resolves to an aarch64 build on x86_64 machines.

setup() {
	load helpers
	tg_load

	STLSHM="$BATS_TEST_TMPDIR/shm"
	mkdir -p "$STLSHM"
	PROTDLLIST="$STLSHM/ProtonDL.txt"

	STLURLCFG="$BATS_TEST_TMPDIR/url.conf"
	cat > "$STLURLCFG" <<'EOF'
CP_PROTONGE="https://github.com/GloriousEggroll/proton-ge-custom"
CP_PROTONTKG="https://github.com/Frogging-Family/wine-tkg-git"
EOF
	CP_PROTONGE="https://github.com/GloriousEggroll/proton-ge-custom"
	CP_PROTONTKG="https://github.com/Frogging-Family/wine-tkg-git"

	# wget output is irrelevant; jq prints the asset URLs the API would return
	# (in API order: aarch64 before x86_64)
	JQFIXTURE="$BATS_TEST_TMPDIR/assets.txt"
	cat > "$JQFIXTURE" <<'EOF'
https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton11-7/GE-Proton11-7-aarch64.sha512sum
https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton11-7/GE-Proton11-7-aarch64.tar.gz
https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton11-7/GE-Proton11-7-x86_64.sha512sum
https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton11-7/GE-Proton11-7-x86_64.tar.gz
https://github.com/GloriousEggroll/proton-ge-custom/releases/download/v7.x-old/SteamTinkerLaunch-7.x.tar.gz
https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton11-7/Yad.tar.gz
https://github.com/Frogging-Family/wine-tkg-git/releases/download/v10.0/wine-tkg-10.tar.gz
EOF

	mkdir -p "$BATS_TEST_TMPDIR/bin"
	cat > "$BATS_TEST_TMPDIR/bin/wget" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat > "$BATS_TEST_TMPDIR/bin/jq" <<EOF
#!/bin/sh
cat "$JQFIXTURE"
EOF
	# host architecture is stubbed; individual tests override TG_TEST_ARCH
	cat > "$BATS_TEST_TMPDIR/bin/uname" <<'EOF'
#!/bin/sh
echo "${TG_TEST_ARCH:-x86_64}"
EOF
	chmod +x "$BATS_TEST_TMPDIR/bin/wget" "$BATS_TEST_TMPDIR/bin/jq" "$BATS_TEST_TMPDIR/bin/uname"
	export WGET="$BATS_TEST_TMPDIR/bin/wget"
	export JQ="$BATS_TEST_TMPDIR/bin/jq"
	export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "getHostProtonArch: maps x86_64 and amd64 to x86_64" {
	export TG_TEST_ARCH=x86_64
	run getHostProtonArch
	[ "$output" = "x86_64" ]

	export TG_TEST_ARCH=amd64
	run getHostProtonArch
	[ "$output" = "x86_64" ]
}

@test "getHostProtonArch: maps aarch64 and arm64 to aarch64" {
	export TG_TEST_ARCH=aarch64
	run getHostProtonArch
	[ "$output" = "aarch64" ]

	export TG_TEST_ARCH=arm64
	run getHostProtonArch
	[ "$output" = "aarch64" ]
}

@test "getHostProtonArch: prints nothing on unknown architectures" {
	export TG_TEST_ARCH=riscv64
	run getHostProtonArch
	[ -z "$output" ]
}

@test "createDLProtList: x86_64 builds are not dropped by the 7.x filter" {
	run createDLProtList
	run cat "$PROTDLLIST"
	[[ "$output" == *"GE-Proton11-7-x86_64.tar.gz"* ]]
}

@test "createDLProtList: foreign-arch builds are filtered out on x86_64" {
	run createDLProtList
	run cat "$PROTDLLIST"
	[[ "$output" != *"aarch64"* ]]
}

@test "createDLProtList: foreign-arch builds are filtered out on aarch64" {
	export TG_TEST_ARCH=aarch64
	run createDLProtList
	run cat "$PROTDLLIST"
	[[ "$output" == *"GE-Proton11-7-aarch64.tar.gz"* ]]
	[[ "$output" != *"x86_64"* ]]
}

@test "createDLProtList: builds without an architecture suffix are kept" {
	run createDLProtList
	run cat "$PROTDLLIST"
	[[ "$output" == *"wine-tkg-10.tar.gz"* ]]
}

@test "createDLProtList: real 7.x tarballs and Yad builds are still filtered" {
	run createDLProtList
	run cat "$PROTDLLIST"
	[[ "$output" != *"SteamTinkerLaunch-7.x.tar.gz"* ]]
	[[ "$output" != *"Yad.tar.gz"* ]]
}

@test "createDLProtList: non-archive assets are ignored" {
	run createDLProtList
	run cat "$PROTDLLIST"
	[[ "$output" != *".sha512sum"* ]]
}

@test "pickHostProton: prefers the host architecture over the first foreign line" {
	local OUT
	OUT="$(printf '%s\n' 'GE-Proton11-7-aarch64.tar.gz' 'GE-Proton11-7-x86_64.tar.gz' | pickHostProton)"
	[ "$OUT" = "GE-Proton11-7-x86_64.tar.gz" ]
}

@test "pickHostProton: falls back to the first line when nothing matches" {
	local OUT
	OUT="$(printf '%s\n' 'Proton-47.11-FWX-3.tar.gz' | pickHostProton)"
	[ "$OUT" = "Proton-47.11-FWX-3.tar.gz" ]
}

@test "dlLatestGE: picks the host-arch build when aarch64 is listed first" {
	StatusWindow() { printf '%s\n' "$*" > "$BATS_TEST_TMPDIR/statusargs.txt"; }

	run dlLatestGE "latestge"
	[ "$status" -eq 0 ]
	run cat "$BATS_TEST_TMPDIR/statusargs.txt"
	[[ "$output" == *"GE-Proton11-7-x86_64.tar.gz"* ]]
	[[ "$output" != *"aarch64"* ]]
}

@test "dlLatestGE: latestge ignores a TKG build listed first" {
	createDLProtList() {
		ProtonDLList=(
			"https://github.com/Frogging-Family/wine-tkg-git/releases/download/v10.0/wine-tkg-10.tar.gz"
			"https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton11-7/GE-Proton11-7-x86_64.tar.gz"
		)
		ProtonDLDispList=("wine-tkg-10.tar.gz" "GE-Proton11-7-x86_64.tar.gz")
	}
	StatusWindow() { printf '%s\n' "$*" > "$BATS_TEST_TMPDIR/statusargs.txt"; }

	run dlLatestGE "latestge"
	[ "$status" -eq 0 ]
	run cat "$BATS_TEST_TMPDIR/statusargs.txt"
	[[ "$output" == *"proton-ge-custom"* ]]
	[[ "$output" != *"wine-tkg"* ]]
}

@test "dlLatestGE: latesttkg picks TKG and not the GE build listed first" {
	createDLProtList() {
		ProtonDLList=(
			"https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton11-7/GE-Proton11-7-x86_64.tar.gz"
			"https://github.com/Frogging-Family/wine-tkg-git/releases/download/v10.0/wine-tkg-10.tar.gz"
		)
		ProtonDLDispList=("GE-Proton11-7-x86_64.tar.gz" "wine-tkg-10.tar.gz")
	}
	StatusWindow() { printf '%s\n' "$*" > "$BATS_TEST_TMPDIR/statusargs.txt"; }

	run dlLatestGE "latesttkg"
	[ "$status" -eq 0 ]
	run cat "$BATS_TEST_TMPDIR/statusargs.txt"
	[[ "$output" == *"wine-tkg-10.tar.gz"* ]]
	[[ "$output" != *"GE-Proton"* ]]
}

@test "dlLatestGE: fails instead of downloading another provider's build" {
	createDLProtList() {
		ProtonDLList=("https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton11-7/GE-Proton11-7-x86_64.tar.gz")
		ProtonDLDispList=("GE-Proton11-7-x86_64.tar.gz")
	}
	StatusWindow() { printf '%s\n' "$*" > "$BATS_TEST_TMPDIR/statusargs.txt"; }

	run dlLatestGE "latesttkg"
	[ "$status" -eq 1 ]
	[ ! -f "$BATS_TEST_TMPDIR/statusargs.txt" ]
}

@test "dlLatestGE: forwards the second argument to dlCustomProton" {
	StatusWindow() { printf '%s\n' "$*" > "$BATS_TEST_TMPDIR/statusargs.txt"; }

	run dlLatestGE "lge" "X"
	[ "$status" -eq 0 ]
	run cat "$BATS_TEST_TMPDIR/statusargs.txt"
	[[ "$output" == *"GE-Proton11-7-x86_64.tar.gz X"* ]]
}

@test "resolveProtonDownloadURL: matches the basename exactly, with optional arch suffix" {
	local OUT
	OUT="$(printf '%s\n' \
		"https://example.invalid/Proton-10a0.tar.gz" \
		"https://example.invalid/Proton-10.0.tar.gz" \
		| resolveProtonDownloadURL "Proton-10.0")"
	[ "$OUT" = "https://example.invalid/Proton-10.0.tar.gz" ]

	OUT="$(printf '%s\n' "https://example.invalid/GE-Proton11-7-x86_64.tar.gz" \
		| resolveProtonDownloadURL "GE-Proton11-7")"
	[ "$OUT" = "https://example.invalid/GE-Proton11-7-x86_64.tar.gz" ]

	# a substring-like request must not resolve to 'Proton-10a0'
	OUT="$(printf '%s\n' \
		"https://example.invalid/Proton-10a0.tar.gz" \
		"https://example.invalid/Proton-10.0.tar.gz" \
		| resolveProtonDownloadURL "Proton-10" || true)"
	[ -z "$OUT" ]
}

@test "switchProton: auto-pull downloads exactly the requested version" {
	getProtPathFromCSV() { echo "$BATS_TEST_TMPDIR/not-installed.csv"; }
	AUTOPULLPROTON=1
	createDLProtList() {
		ProtonDLList=(
			"https://example.invalid/Proton-10a0.tar.gz"
			"https://example.invalid/Proton-10.0.tar.gz"
		)
		ProtonDLDispList=("Proton-10a0.tar.gz" "Proton-10.0.tar.gz")
	}
	StatusWindow() { printf '%s\n' "$*" > "$BATS_TEST_TMPDIR/statusargs.txt"; }

	run switchProton "Proton-10.0"
	[ "$status" -eq 0 ]
	run cat "$BATS_TEST_TMPDIR/statusargs.txt"
	[[ "$output" == *"https://example.invalid/Proton-10.0.tar.gz"* ]]
	[[ "$output" != *"Proton-10a0"* ]]
}

# Minimal YAD stand-in: records argv, drains list stdin to $FAKEYAD_STDIN and
# prints $FAKEYAD_PICK (set to force a choice, empty set forces no choice).
setup_fake_yad() {
	mkdir -p "$BATS_TEST_TMPDIR/bin"
	# quoted heredoc: environment variables must stay literal until yad runs
	cat > "$BATS_TEST_TMPDIR/bin/yad" <<'EOF'
#!/bin/sh
printf '%s\n' '===' >>"$FAKEYAD_CALLS"
printf '%s\n' "$@" >>"$FAKEYAD_CALLS"
for arg in "$@"; do
	case "$arg" in
		--list)
			cat >"$FAKEYAD_STDIN"
			PICK=""
			ROW="$(head -n1 "$FAKEYAD_STDIN")"
			case "$ROW" in
				*'|'*) PICK="${ROW#*|}" ;;
				*) PICK="$ROW" ;;
			esac
			if [ "${FAKEYAD_PICK+set}" = set ]; then PICK="$FAKEYAD_PICK"; fi
			if [ -n "$PICK" ]; then printf '%s\n' "$PICK"; fi
			exit "${FAKEYAD_RC:-0}"
			;;
		--entry)
			if [ -n "${FAKEYAD_ENTRY:-}" ]; then printf '%s\n' "$FAKEYAD_ENTRY"; fi
			exit "${FAKEYAD_ENTRY_RC:-0}"
			;;
	esac
done
exit 0
EOF
	chmod +x "$BATS_TEST_TMPDIR/bin/yad"
	export FAKEYAD_CALLS="$BATS_TEST_TMPDIR/yad.calls"
	: >"$FAKEYAD_CALLS"
	export FAKEYAD_STDIN="$BATS_TEST_TMPDIR/yad.stdin"
	: >"$FAKEYAD_STDIN"
	export STATUSWIN_CALLS="$BATS_TEST_TMPDIR/statuswin.calls"
	: >"$STATUSWIN_CALLS"
	export YAD="$BATS_TEST_TMPDIR/bin/yad"
}

@test "dlCustomProtonGUI: opens a list window with the Proton versions" {
	# window geometry and the post-download list refresh are not what this
	# test covers
	pollWinRes() { :; }
	StatusWindow() { printf '%s\n' "$*" >>"$STATUSWIN_CALLS"; }
	createProtonList() { :; }

	setup_fake_yad

	run createDLProtList
	run dlCustomProtonGUI

	[ "$status" -eq 0 ]
	# the dialog must be a list window (not a combobox) so the grab can't be
	# lost when the mouse is released
	grep -q -- "--list" "$FAKEYAD_CALLS"
	grep -q -- "--column" "$FAKEYAD_CALLS"
	# the URL travels in a hidden column and is what gets printed
	grep -q -- "--hide-column=2" "$FAKEYAD_CALLS"
	grep -q -- "--print-column=2" "$FAKEYAD_CALLS"
	# the selected Proton version resolves to its download URL downstream
	grep -q -- "GE-Proton11-7-x86_64.tar.gz" "$STATUSWIN_CALLS"
}

@test "dlCustomProtonGUI: a near-identical name resolves to the selected URL" {
	pollWinRes() { :; }
	createProtonList() { touch "$BATS_TEST_TMPDIR/refreshed"; }
	StatusWindow() { printf '%s\n' "$*" > "$BATS_TEST_TMPDIR/statusargs.txt"; }
	createDLProtList() {
		ProtonDLList=(
			"https://example.invalid/Proton-10a0.tar.gz"
			"https://example.invalid/Proton-10.0.tar.gz"
		)
		ProtonDLDispList=("Proton-10a0.tar.gz" "Proton-10.0.tar.gz")
	}
	setup_fake_yad
	# the user picks the second row
	export FAKEYAD_PICK="https://example.invalid/Proton-10.0.tar.gz"

	run dlCustomProtonGUI
	[ "$status" -eq 0 ]
	# every row carries name and URL together
	grep -q "Proton-10.0.tar.gz|https://example.invalid/Proton-10.0.tar.gz" "$FAKEYAD_STDIN"
	[ -f "$BATS_TEST_TMPDIR/refreshed" ]
	run cat "$BATS_TEST_TMPDIR/statusargs.txt"
	[[ "$output" == *"https://example.invalid/Proton-10.0.tar.gz"* ]]
	[[ "$output" != *"Proton-10a0"* ]]
}

@test "dlCustomProtonGUI: cancelling the list downloads nothing" {
	pollWinRes() { :; }
	createProtonList() { touch "$BATS_TEST_TMPDIR/refreshed"; }
	StatusWindow() { touch "$BATS_TEST_TMPDIR/statusargs.txt"; }
	createDLProtList() {
		ProtonDLList=("https://example.invalid/Proton-10.0.tar.gz")
		ProtonDLDispList=("Proton-10.0.tar.gz")
	}
	setup_fake_yad
	export FAKEYAD_RC=1

	run dlCustomProtonGUI
	[ "$status" -eq 0 ]
	[ ! -f "$BATS_TEST_TMPDIR/statusargs.txt" ]
	[ ! -f "$BATS_TEST_TMPDIR/refreshed" ]
}

@test "dlCustomProtonGUI: OK without a selection downloads nothing" {
	pollWinRes() { :; }
	createProtonList() { touch "$BATS_TEST_TMPDIR/refreshed"; }
	StatusWindow() { touch "$BATS_TEST_TMPDIR/statusargs.txt"; }
	createDLProtList() {
		ProtonDLList=("https://example.invalid/Proton-10.0.tar.gz")
		ProtonDLDispList=("Proton-10.0.tar.gz")
	}
	setup_fake_yad
	export FAKEYAD_RC=0
	export FAKEYAD_PICK=""

	run dlCustomProtonGUI
	[ "$status" -eq 0 ]
	[ ! -f "$BATS_TEST_TMPDIR/statusargs.txt" ]
	[ ! -f "$BATS_TEST_TMPDIR/refreshed" ]
}

@test "dlCustomProtonGUI: the URL button opens manual entry" {
	pollWinRes() { :; }
	createProtonList() { touch "$BATS_TEST_TMPDIR/refreshed"; }
	StatusWindow() { printf '%s\n' "$*" > "$BATS_TEST_TMPDIR/statusargs.txt"; }
	createDLProtList() {
		ProtonDLList=("https://example.invalid/Proton-10.0.tar.gz")
		ProtonDLDispList=("Proton-10.0.tar.gz")
	}
	setup_fake_yad
	export FAKEYAD_RC=3            # user pressed the URL button
	export FAKEYAD_ENTRY="https://example.invalid/Manual-6.9.tar.gz"

	run dlCustomProtonGUI
	[ "$status" -eq 0 ]
	grep -q -- "--entry" "$FAKEYAD_CALLS"
	[ -f "$BATS_TEST_TMPDIR/refreshed" ]
	run cat "$BATS_TEST_TMPDIR/statusargs.txt"
	[[ "$output" == *"https://example.invalid/Manual-6.9.tar.gz"* ]]
}

@test "dlCustomProtonGUI: cancelling manual entry downloads nothing" {
	pollWinRes() { :; }
	createProtonList() { touch "$BATS_TEST_TMPDIR/refreshed"; }
	StatusWindow() { touch "$BATS_TEST_TMPDIR/statusargs.txt"; }
	createDLProtList() {
		ProtonDLList=("https://example.invalid/Proton-10.0.tar.gz")
		ProtonDLDispList=("Proton-10.0.tar.gz")
	}
	setup_fake_yad
	export FAKEYAD_RC=3
	export FAKEYAD_ENTRY_RC=1

	run dlCustomProtonGUI
	[ "$status" -eq 0 ]
	[ ! -f "$BATS_TEST_TMPDIR/statusargs.txt" ]
	[ ! -f "$BATS_TEST_TMPDIR/refreshed" ]
}

@test "dlCustomProtonGUI: a non-URL manual entry is rejected" {
	pollWinRes() { :; }
	createProtonList() { touch "$BATS_TEST_TMPDIR/refreshed"; }
	StatusWindow() { touch "$BATS_TEST_TMPDIR/statusargs.txt"; }
	createDLProtList() {
		ProtonDLList=("https://example.invalid/Proton-10.0.tar.gz")
		ProtonDLDispList=("Proton-10.0.tar.gz")
	}
	setup_fake_yad
	export FAKEYAD_RC=3
	export FAKEYAD_ENTRY="not-an-url"

	run dlCustomProtonGUI
	[ "$status" -eq 1 ]
	[ ! -f "$BATS_TEST_TMPDIR/statusargs.txt" ]
	[ ! -f "$BATS_TEST_TMPDIR/refreshed" ]
}

@test "dlCustomProtonGUI: reports a failed download to the caller" {
	pollWinRes() { :; }
	createProtonList() { :; }
	StatusWindow() { return 1; }
	createDLProtList() {
		ProtonDLList=("https://example.invalid/Proton-10.0.tar.gz")
		ProtonDLDispList=("Proton-10.0.tar.gz")
	}
	setup_fake_yad

	run dlCustomProtonGUI
	[ "$status" -eq 1 ]
}
