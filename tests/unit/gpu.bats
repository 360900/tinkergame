#!/usr/bin/env bash
# Tests for the vendor-neutral dGPU offload (checkPrimerun / findOffloadGpu)
# against a fake /sys/class/drm tree, and for the MAKO launch wrapper.

load helpers

setup() {
	tg_load
	DRMSYSDIR="$BATS_TEST_TMPDIR/drm"
	PCIDIR="$BATS_TEST_TMPDIR/pci"
	DRVDIR="$BATS_TEST_TMPDIR/drivers"
	mkdir -p "$DRMSYSDIR" "$PCIDIR" "$DRVDIR"
	unset __NV_PRIME_RENDER_OFFLOAD __VK_LAYER_NV_optimus __GLX_VENDOR_LIBRARY_NAME DRI_PRIME
	USEPRIMERUN=1
}

# addGpu <cardN> <pci slot> <driver> <boot_vga>
addGpu() {
	mkdir -p "$PCIDIR/$2" "$DRVDIR/$3" "$DRMSYSDIR/$1"
	ln -s "$DRVDIR/$3" "$PCIDIR/$2/driver"
	echo "$4" > "$PCIDIR/$2/boot_vga"
	ln -s "$PCIDIR/$2" "$DRMSYSDIR/$1/device"
	mkdir -p "$DRMSYSDIR/$1-eDP-1"
}

@test "AMD dGPU next to an AMD iGPU gets DRI_PRIME with its PCI tag" {
	addGpu card0 0000:c1:00.0 amdgpu 1
	addGpu card1 0000:03:00.0 amdgpu 0
	checkPrimerun
	[ "$DRI_PRIME" = "pci-0000_03_00_0" ]
	[ -z "${__NV_PRIME_RENDER_OFFLOAD:-}" ]
}

@test "NVIDIA proprietary dGPU gets the PRIME render offload variables" {
	addGpu card0 0000:00:02.0 i915 1
	addGpu card1 0000:01:00.0 nvidia 0
	checkPrimerun
	[ "$__NV_PRIME_RENDER_OFFLOAD" = "1" ]
	[ "$__VK_LAYER_NV_optimus" = "NVIDIA_only" ]
	[ "$__GLX_VENDOR_LIBRARY_NAME" = "nvidia" ]
	[ -z "${DRI_PRIME:-}" ]
}

@test "nouveau and Intel Arc dGPUs use DRI_PRIME" {
	addGpu card0 0000:00:02.0 i915 1
	addGpu card1 0000:01:00.0 nouveau 0
	checkPrimerun
	[ "$DRI_PRIME" = "pci-0000_01_00_0" ]

	unset DRI_PRIME
	rm -rf "${DRMSYSDIR:?}/card1"
	addGpu card2 0000:04:00.0 xe 0
	checkPrimerun
	[ "$DRI_PRIME" = "pci-0000_04_00_0" ]
}

@test "single GPU sets nothing" {
	addGpu card0 0000:03:00.0 amdgpu 1
	checkPrimerun
	[ -z "${DRI_PRIME:-}" ]
	[ -z "${__NV_PRIME_RENDER_OFFLOAD:-}" ]
}

@test "Intel iGPU is never picked even when it is not the boot GPU" {
	addGpu card0 0000:01:00.0 amdgpu 1
	addGpu card1 0000:00:02.0 i915 0
	checkPrimerun
	[ -z "${DRI_PRIME:-}" ]
}

@test "non-PCI DRM devices are ignored" {
	mkdir -p "$BATS_TEST_TMPDIR/platform/simple-framebuffer.0" "$DRMSYSDIR/card0"
	ln -s "$BATS_TEST_TMPDIR/platform/simple-framebuffer.0" "$DRMSYSDIR/card0/device"
	checkPrimerun
	[ -z "${DRI_PRIME:-}" ]
}

@test "disabled toggle sets nothing" {
	USEPRIMERUN=0
	addGpu card0 0000:00:02.0 i915 1
	addGpu card1 0000:01:00.0 nvidia 0
	checkPrimerun
	[ -z "${__NV_PRIME_RENDER_OFFLOAD:-}" ]
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
