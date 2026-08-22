#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function writelog {
# LOGLEVEL=0: disable log

# LOGLEVEL=1: log only:
LOGONE="404,ERROR,SKIP,WARN,CREATE"

# LOGLEVEL=2: log also - including:
#LOGTWO="HACK,INFO,NEW,UPDATE,WAIT"

	if [ -n "$4" ] && [ "$3" == "X" ] && grep -q ".log" <<< "$4"; then
		echo "$(date) $1 - $2" | tee -a "$4" >/dev/null
	else
		if [ -z "$LOGLEVEL" ]; then
			LOGLEVEL=2
		fi

		if [ "$LOGLEVEL" -eq 1 ]; then
			if grep -q "$1" <<< "$LOGONE"; then
				if [ -z "$LOGFILE" ]; then
					echo "$(date) $1 - $2" | tee -a "$TEMPLOG" >/dev/null
				else
					echo "$(date) $1 - $2" | tee -a "$TEMPLOG" "$LOGFILE" >/dev/null
				fi
			fi
		fi

		if [ "$LOGLEVEL" -eq 2 ]; then
			if [ -z "$LOGFILE" ]; then
				echo "$(date) $1 - $2" | tee -a "$TEMPLOG" >/dev/null
			else
				echo "$(date) $1 - $2" | tee -a "$TEMPLOG" "$LOGFILE" >/dev/null
			fi
		fi

		if [ -n "$3" ]; then
			if [ "$3" == "E" ]; then
				echo "$(date) $1 - $2"
			elif [ "$3" == "P" ] && [ -f "$PRELOG" ]; then
				echo "$(date) $1 - $2" | tee -a "$PRELOG" >/dev/null
			elif grep -q ".log" <<< "$3"; then
				echo "$(date) $1 - $2" | tee -a "$3" >/dev/null
			fi
		fi
	fi
}

# generic git clone/pull function
