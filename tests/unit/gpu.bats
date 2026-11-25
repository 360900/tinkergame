#!/usr/bin/env bash
# Tests for the dGPU toggle (checkPrimerun / detectDgpu with a stubbed switcherooctl
# and a fake /sys/class/drm tree), hiding it without a dGPU, and the MAKO launch wrapper.

bats_require_minimum_version 1.5.0

load helpers

NVIDIALIST='Device: 0
  Name:        Intel Corporation Alder Lake-P GT2 [Iris Xe Graphics]
  Default:     yes
  Discrete:    no
  Environment: DRI_PRIME=pci-0000_00_02_0
Device: 1
  Name:        NVIDIA Corporation GA107M [GeForce RTX 3050 Mobile]
  Default:     no
  Discrete:    yes
  Environment: __GLX_VENDOR_LIBRARY_NAME=nvidia __NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only'

AMDLIST='Device: 0
  Name:        Advanced Micro Devices, Inc. [AMD/ATI] Phoenix1
  Default:     yes
  Discrete:    no
  Environment: DRI_PRIME=pci-0000_c1_00_0 VK_LOADER_DRIVERS_SELECT=*radeon*
Device: 1
  Name:        Advanced Micro Devices, Inc. [AMD/ATI] Navi 33 [Radeon RX 7700S]
  Default:     no
  Discrete:    yes
  Environment: DRI_PRIME=pci-0000_03_00_0 VK_LOADER_DRIVERS_SELECT=*radeon*'

setup() {
	tg_load
	DRMSYSDIR="$BATS_TEST_TMPDIR/drm"
	STLSHM="$BATS_TEST_TMPDIR/shm"
	DGPUSTATE="$STLSHM/dgpu.txt"
	mkdir -p "$DRMSYSDIR" "$STLSHM"
	SWITCHEROOCTL="$BATS_TEST_TMPDIR/switcherooctl"
	SWLIST="$BATS_TEST_TMPDIR/swlist"
	SWCALLS="$BATS_TEST_TMPDIR/swcalls"
	printf '#!/bin/sh\necho call >> "%s"\ncat "%s" 2>/dev/null\n' "$SWCALLS" "$SWLIST" > "$SWITCHEROOCTL"
	chmod +x "$SWITCHEROOCTL"
	unset __NV_PRIME_RENDER_OFFLOAD __VK_LAYER_NV_optimus __GLX_VENDOR_LIBRARY_NAME DRI_PRIME VK_LOADER_DRIVERS_SELECT
	unset DGPUCARDS DGPUENV
	USEPRIMERUN=1
}

# addCards <count>: cardN dirs plus a connector, which must not count as a GPU
addCards() {
	local i
	for ((i = 0; i < $1; i++)); do
		mkdir -p "$DRMSYSDIR/card$i" "$DRMSYSDIR/card$i-eDP-1"
	done
}

swCalls() {
	if [ -f "$SWCALLS" ]; then wc -l < "$SWCALLS"; else echo 0; fi
}

@test "NVIDIA dGPU gets the PRIME render offload variables from switcheroo-control" {
	addCards 2
	echo "$NVIDIALIST" > "$SWLIST"
	checkPrimerun
	[ "$__NV_PRIME_RENDER_OFFLOAD" = "1" ]
	[ "$__VK_LAYER_NV_optimus" = "NVIDIA_only" ]
	[ "$__GLX_VENDOR_LIBRARY_NAME" = "nvidia" ]
	[ -z "${DRI_PRIME:-}" ]
}

@test "AMD dGPU gets DRI_PRIME and the Vulkan driver selection without glob expansion" {
	addCards 2
	echo "$AMDLIST" > "$SWLIST"
	# a file matching the glob must not replace the value
	touch "$BATS_TEST_TMPDIR/xradeonx"
	cd "$BATS_TEST_TMPDIR"
	checkPrimerun
	[ "$DRI_PRIME" = "pci-0000_03_00_0" ]
	[ "$VK_LOADER_DRIVERS_SELECT" = "*radeon*" ]
	[ -z "${__NV_PRIME_RENDER_OFFLOAD:-}" ]
}

@test "single GPU: no dGPU and switcheroo-control is not even asked" {
	addCards 1
	echo "$NVIDIALIST" > "$SWLIST"
	run ! haveDgpu
	checkPrimerun
	[ -z "${__NV_PRIME_RENDER_OFFLOAD:-}" ]
	[ "$(swCalls)" -eq 0 ]
}

@test "dGPU that already is the default GPU leaves nothing to switch to" {
	addCards 2
	sed 's/Default:     yes/Default:     XX/;s/Default:     no/Default:     yes/;s/Default:     XX/Default:     no/' <<< "$NVIDIALIST" > "$SWLIST"
	run ! haveDgpu
}

@test "two integrated GPUs are not treated as a dGPU" {
	addCards 2
	sed 's/Discrete:    yes/Discrete:    no/' <<< "$NVIDIALIST" > "$SWLIST"
	run ! haveDgpu
}

@test "switcheroo-control before 3.0 (no Discrete key) uses the non-default GPU" {
	addCards 2
	grep -v "Discrete:" <<< "$AMDLIST" > "$SWLIST"
	checkPrimerun
	[ "$DRI_PRIME" = "pci-0000_03_00_0" ]
}

@test "missing switcherooctl: no dGPU, nothing cached" {
	addCards 2
	SWITCHEROOCTL="switcherooctl-missing-test"
	run ! haveDgpu
	[ ! -f "$DGPUSTATE" ]
}

@test "switcheroo-control service not running: no dGPU, nothing cached" {
	addCards 2
	run ! haveDgpu
	[ "$(swCalls)" -eq 1 ]
	[ ! -f "$DGPUSTATE" ]
}

@test "result is cached per boot and detected again when the GPU count changes" {
	addCards 2
	echo "$NVIDIALIST" > "$SWLIST"
	haveDgpu
	unset DGPUCARDS DGPUENV
	haveDgpu
	[ "$(swCalls)" -eq 1 ]
	[ "$(head -n1 "$DGPUSTATE")" = "2" ]

	# eGPU unplugged
	rm -rf "${DRMSYSDIR:?}"/card1*
	unset DGPUCARDS DGPUENV
	run ! haveDgpu
}

@test "disabled toggle sets nothing" {
	USEPRIMERUN=0
	addCards 2
	echo "$NVIDIALIST" > "$SWLIST"
	checkPrimerun
	[ -z "${__NV_PRIME_RENDER_OFFLOAD:-}" ]
	[ "$(swCalls)" -eq 0 ]
}

@test "dGPU settings entry exists only with a dGPU and the cache follows hardware changes" {
	STLRAWENTRIES="$STLSHM/rawentries.txt"
	STLSETENTRIES="$STLSHM/setentries.txt"
	STLSETENTRIESREQ="$STLSHM/setentries-req.txt"
	MTEMP="$STLSHM/menutemp"
	TGSRC_SETENTRIES="$BATS_TEST_TMPDIR/srcentries.sh"
	cat > "$TGSRC_SETENTRIES" <<'EOF'
#STARTSETENTRIES
	--field="     $GUI_A!$DESC_A ('USEA')":CHK "${USEA/#-/ -}" `#CAT_Tools` `#SUB_Checkbox` `#MENU_GAME` \
	--field="     $GUI_USEPRIMERUN!$DESC_USEPRIMERUN ('USEPRIMERUN')":CHK "${USEPRIMERUN/#-/ -}" `#CAT_Tools` `#SUB_Checkbox` `#MENU_GAME` `#REQ_DGPU` \
#ENDSETENTRIES
EOF
	touch -d '2020-01-01 00:00:00' "$TGSRC_SETENTRIES"
	addCards 1
	listAllSettingsEntries
	grep -qx "USEA" "$STLSETENTRIES"
	run ! grep -q "USEPRIMERUN" "$STLSETENTRIES" "$STLRAWENTRIES"

	addCards 2
	echo "$NVIDIALIST" > "$SWLIST"
	unset DGPUCARDS DGPUENV
	listAllSettingsEntries
	grep -qx "USEPRIMERUN" "$STLSETENTRIES"
	grep -q "('USEPRIMERUN')" "$STLRAWENTRIES"
	[ "$(grep -c -- "--field" "$STLRAWENTRIES")" -eq 2 ]
}

@test "real settings entries tag the dGPU toggle" {
	grep "('USEPRIMERUN')" "$TG_ROOT/lib/gui/settings-entries.sh" | grep -q '`#REQ_DGPU`'
}

@test "MAKO settings entry exists only when mako-launch is installed" {
	STLRAWENTRIES="$STLSHM/rawentries.txt"
	STLSETENTRIES="$STLSHM/setentries.txt"
	STLSETENTRIESREQ="$STLSHM/setentries-req.txt"
	MTEMP="$STLSHM/menutemp"
	TGSRC_SETENTRIES="$BATS_TEST_TMPDIR/srcentries.sh"
	cat > "$TGSRC_SETENTRIES" <<'EOF'
#STARTSETENTRIES
	--field="     $GUI_A!$DESC_A ('USEA')":CHK "${USEA/#-/ -}" `#CAT_Tools` `#SUB_Checkbox` `#MENU_GAME` \
	--field="     $GUI_USEMAKO!$DESC_USEMAKO ('USEMAKO')":CHK "${USEMAKO/#-/ -}" `#CAT_Tools` `#SUB_Checkbox` `#MENU_GAME` `#REQ_MAKO` \
#ENDSETENTRIES
EOF
	touch -d '2020-01-01 00:00:00' "$TGSRC_SETENTRIES"
	addCards 1
	HOME="$BATS_TEST_TMPDIR/home"
	MAKOLAUNCH="mako-launch-hidden-test"
	listAllSettingsEntries
	grep -qx "USEA" "$STLSETENTRIES"
	run ! grep -q "USEMAKO" "$STLSETENTRIES" "$STLRAWENTRIES"

	mkdir -p "$HOME/.local/bin"
	printf '#!/bin/sh\nexec "$@"\n' > "$HOME/.local/bin/$MAKOLAUNCH"
	chmod +x "$HOME/.local/bin/$MAKOLAUNCH"
	listAllSettingsEntries
	grep -qx "USEMAKO" "$STLSETENTRIES"
	grep -q "('USEMAKO')" "$STLRAWENTRIES"
}

@test "real settings entries tag the MAKO toggle" {
	grep "('USEMAKO')" "$TG_ROOT/lib/gui/settings-entries.sh" | grep -q '`#REQ_MAKO`'
}

@test "MAKO is found in ~/.local/bin when not in PATH" {
	HOME="$BATS_TEST_TMPDIR/home"
	mkdir -p "$HOME/.local/bin"
	printf '#!/bin/sh\nexec "$@"\n' > "$HOME/.local/bin/mako-launch"
	chmod +x "$HOME/.local/bin/mako-launch"
	USEMAKO=1
	setMakoCmd
	[ "$MAKOC" = "$HOME/.local/bin/mako-launch" ]
}

@test "missing MAKO disables the option" {
	HOME="$BATS_TEST_TMPDIR/nohome"
	MAKOLAUNCH="mako-launch-missing-test"
	USEMAKO=1
	notiShow() { :; }
	setMakoCmd
	[ -z "$MAKOC" ]
	[ "$USEMAKO" -eq 0 ]
}

@test "old PrimeRun collection still loads the renamed DedicatedGPU config" {
	mkdir -p "$BATS_TEST_TMPDIR/coll"
	cp "$TG_ROOT/collections/DedicatedGPU.conf" "$BATS_TEST_TMPDIR/coll/"
	[ "$(findCollectionConf "$BATS_TEST_TMPDIR/coll" "PrimeRun")" = "$BATS_TEST_TMPDIR/coll/DedicatedGPU.conf" ]
	[ "$(findCollectionConf "$BATS_TEST_TMPDIR/coll" "dedicatedgpu")" = "$BATS_TEST_TMPDIR/coll/DedicatedGPU.conf" ]
	grep -qx 'USEPRIMERUN="1"' "$BATS_TEST_TMPDIR/coll/DedicatedGPU.conf"
}

@test "a user's own PrimeRun.conf wins over the renamed config" {
	mkdir -p "$BATS_TEST_TMPDIR/coll"
	touch "$BATS_TEST_TMPDIR/coll/PrimeRun.conf" "$BATS_TEST_TMPDIR/coll/DedicatedGPU.conf"
	[ "$(findCollectionConf "$BATS_TEST_TMPDIR/coll" "PrimeRun")" = "$BATS_TEST_TMPDIR/coll/PrimeRun.conf" ]
	[ -z "$(findCollectionConf "$BATS_TEST_TMPDIR/coll" "Other")" ]
}
