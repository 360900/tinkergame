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
	StatusWindow() { printf '%s\n' "$2" > "$BATS_TEST_TMPDIR/statusargs.txt"; }

	run dlLatestGE "latestge"
	run cat "$BATS_TEST_TMPDIR/statusargs.txt"
	[[ "$output" == *"GE-Proton11-7-x86_64.tar.gz"* ]]
	[[ "$output" != *"aarch64"* ]]
}
