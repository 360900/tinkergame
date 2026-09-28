#!/usr/bin/env bash
# Regression tests for the downloadable custom Proton list.
#
# The asset filter is a regex and used to say '7.x' unescaped, which also
# matched the dash in GE-Proton11-7-x86_64.tar.gz and silently dropped every
# x86_64 build of any release whose number contains 7 (issue #7).

setup() {
	load helpers
	tg_load

	STLSHM="$BATS_TEST_TMPDIR/shm"
	mkdir -p "$STLSHM"
	PROTDLLIST="$STLSHM/ProtonDL.txt"

	STLURLCFG="$BATS_TEST_TMPDIR/url.conf"
	cat > "$STLURLCFG" <<'EOF'
CP_PROTONGE="https://github.com/GloriousEggroll/proton-ge-custom"
EOF
	CP_PROTONGE="https://github.com/GloriousEggroll/proton-ge-custom"

	# wget output is irrelevant; jq prints the asset URLs the API would return
	JQFIXTURE="$BATS_TEST_TMPDIR/assets.txt"
	cat > "$JQFIXTURE" <<'EOF'
https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton11-7/GE-Proton11-7-x86_64.tar.gz
https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton11-7/GE-Proton11-7-aarch64.tar.gz
https://github.com/GloriousEggroll/proton-ge-custom/releases/download/v7.x-old/SteamTinkerLaunch-7.x.tar.gz
https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton11-7/Yad.tar.gz
https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton11-7/GE-Proton11-7-x86_64.sha512sum
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
	chmod +x "$BATS_TEST_TMPDIR/bin/wget" "$BATS_TEST_TMPDIR/bin/jq"
	export WGET="$BATS_TEST_TMPDIR/bin/wget"
	export JQ="$BATS_TEST_TMPDIR/bin/jq"
}

@test "createDLProtList: x86_64 builds are not dropped by the 7.x filter" {
	run createDLProtList
	run cat "$PROTDLLIST"
	[[ "$output" == *"GE-Proton11-7-x86_64.tar.gz"* ]]
}

@test "createDLProtList: aarch64 builds are still listed" {
	run createDLProtList
	run cat "$PROTDLLIST"
	[[ "$output" == *"GE-Proton11-7-aarch64.tar.gz"* ]]
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
