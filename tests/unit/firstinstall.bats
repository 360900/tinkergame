#!/usr/bin/env bash
# Unit tests for the incoming command line parsing in the launch pipeline.

load helpers

setup() {
	tg_load
}

@test "getCurrentCommandline: a plain game launch sets HAVEINPROTON=0" {
	getCurrentCommandline waitforexitandrun /path/steamapps/common/Game/game.exe
	[ "$HAVEINPROTON" -eq 0 ]
}

@test "getCurrentCommandline: an incoming Proton command sets HAVEINPROTON=1" {
	getCurrentCommandline proton waitforexitandrun /path/game.exe
	[ "$HAVEINPROTON" -eq 1 ]
}

@test "getCurrentCommandline: an iscriptevaluator run leaves HAVEINPROTON=0" {
	# checkFirstTimeRun does the real evaluator work; this test only covers the
	# parsing, so stub it out.
	checkFirstTimeRun() { :; }

	getCurrentCommandline run /path/legacycompat/iscriptevaluator.exe 'legacycompat\evaluatorscript_413150.vdf'
	[ "$HAVEINPROTON" -eq 0 ]
}
