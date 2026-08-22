#!/usr/bin/env bash
# Tests for the Steam 'stop' verb short-circuit in the bootstrap dispatch.

load helpers

setup() {
	tg_load
}

@test "isStopVerbInvocation: recognizes the stop verb in the leading arguments" {
	run isStopVerbInvocation "stop" "/path/steamapps/common/Game/game.exe"
	[ "$status" -eq 0 ]

	run isStopVerbInvocation "run" "stop" "/path/steamapps/common/Game/game.exe"
	[ "$status" -eq 0 ]

	run isStopVerbInvocation "waitforexitandrun" "stop" "/path/steamapps/common/Game/game.exe"
	[ "$status" -eq 0 ]
}

@test "isStopVerbInvocation: regular launches are not stop requests" {
	run isStopVerbInvocation "waitforexitandrun" "/path/steamapps/common/Game/game.exe"
	[ "$status" -ne 0 ]

	run isStopVerbInvocation "run" "/path/steamapps/common/Game/game.exe" "-stop" "arg"
	[ "$status" -ne 0 ]

	run isStopVerbInvocation "game" "onetimerun" "/path/steamapps/common/Game/game.exe"
	[ "$status" -ne 0 ]
}

@test "handleStopVerb: exits cleanly without launching anything" {
	run handleStopVerb "run" "stop" "/path/steamapps/common/Game/game.exe"
	[ "$status" -eq 0 ]
}
