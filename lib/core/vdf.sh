#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function backupVdfFile {
	ORGVDFNAME="$1"

	VDFBASENAME="$(basename "$ORGVDFNAME")"
	VDFDIRNAME="$(dirname "$ORGVDFNAME")"

	VDFNAME="${VDFBASENAME%%.*}"
	VDFEXT="${VDFBASENAME##*.}"
	BACKUPVDFNAME="${VDFDIRNAME}/${VDFNAME}_tinkergame.${VDFEXT}"
	if [ -f "$ORGVDFNAME" ]; then
		SHOULDBACKUPVDF=1
		if [ -f "$BACKUPVDFNAME" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Found existing VDF backup file '$BACKUPVDFNAME'"
			if [ "$(( $(date +"%s") - $(stat -c "%Y" "$BACKUPVDFNAME") ))" -gt "86400" ]; then  # file age > 1 day
				writelog "INFO" "${FUNCNAME[0]} - Existing VDF backup file is older than 1 day, overwriting"
				rm "$BACKUPVDFNAME"
			else
				writelog "SKIP" "${FUNCNAME[0]} - Existing VDF backup file is not older than 1 day, not overwriting"
				SHOULDBACKUPVDF=0
			fi
		fi

		if [ "$SHOULDBACKUPVDF" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Backing up VDF file '$VDFBASENAME' to '$( basename "$BACKUPVDFNAME" )'"
			cp "$ORGVDFNAME" "$BACKUPVDFNAME"
		else
			writelog "INFO" "${FUNCNAME[0]} - Not backing up VDF file '$VDFBASENAME'"
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - VDF file to back up '$ORGVDFNAME' does not exist -- Nothing to back up"
	fi
}

## Generate string of [[:space:]] to represent indentation in VDF file, useful for searching
function generateVdfIndentString {
	SPACETYPE="${2:-\t}"  # Type of space, expected values could be '\t' (for writing) or '[[:space:]]' (for searching)

    printf "%.0s${SPACETYPE}" $(seq 1 "$1")
}

## Attempt to get the indentation level of the first occurance of a given VDF block
function guessVdfIndent {
    BLOCKNAME="$( safequoteVdfBlockName "$1" )"  # Block to check the indentation level on
    VDF="$2"

    grep -i "${BLOCKNAME}" "$VDF" | head -n1 | awk '{print gsub(/\t/,"")}'
}

## Surround a VDF block name with quotes if it doesn't have any
function safequoteVdfBlockName {
    QUOTEDBLOCKNAME="$1"
    if ! [[ $QUOTEDBLOCKNAME == \"* ]]; then
        QUOTEDBLOCKNAME="\"$QUOTEDBLOCKNAME\""
    fi

    echo "$QUOTEDBLOCKNAME"
}

## Use sed to grab a section of a given VDF file based on its indentation level
## TODO check if ENDPATTERN actually works?
function getVdfSection {
    STARTPATTERN="$( safequoteVdfBlockName "$1" )"
    ENDPATTERN="${2:-\}}"  # Default end pattern to end of block
    INDENT="$3"
    VDF="$4"
	STOPAFTERFIRSTMATCH="$5"

    if [ -z "$INDENT" ]; then
        INDENT="$(( $( guessVdfIndent "$STARTPATTERN" "$VDF" ) ))"
    fi

	# Only generate indent string if given tab length > 0
	# Allows for parsing top-level VDF section i.e. "UserLocalConfigStore" in localconfig.vdf
	INDENTSTR=""
	if [ "$INDENT" -gt 0 ]; then
		INDENTSTR="$( generateVdfIndentString "$INDENT" "[[:space:]]" )"
    else
		writelog "INFO" "${FUNCNAME[0]} - Indent is 0 ($INDENT)"
	fi
	INDENTEDSTARTPATTERN="${INDENTSTR}${STARTPATTERN}"
    INDENTEDENDPATTERN="${INDENTSTR}${ENDPATTERN}"

	writelog "INFO" "${FUNCNAME[0]} - Searching for VDF block with name '$STARTPATTERN' in VDF file '$VDF'"
	writelog "INFO" "${FUNCNAME[0]} - Start pattern is '$INDENTEDSTARTPATTERN'"

	# This is a very hacky solution to allow 'getNestedVdfSection' to use this function
	# It needs the start pattern exact match but other functions can't use this
	if [ -n "$STOPAFTERFIRSTMATCH" ]; then
		sed -n "/^${INDENTEDSTARTPATTERN}/I,/^${INDENTEDENDPATTERN}/I { p; /${INDENTEDENDPATTERN}/I q }" "$VDF"
	else
		sed -n "/^${INDENTEDSTARTPATTERN}/I,/^${INDENTEDENDPATTERN}/I p" "$VDF"
	fi
}

## Check if a VDF block (block_name) already exists inside a parent block (search_block)
## Ex: search_block "CompatToolMapping" for a specific block_name "22320"
function checkVdfSectionAlreadyExists {
    SEARCHBLOCK="$( safequoteVdfBlockName "${1:-\"}" )"  # Default to the first quotation, should be the start VDF file
    BLOCKNAME="$( safequoteVdfBlockName "$2" )"  # Block name to  search for
	VDF="$3"
	INDENT="$4"  # Optional to check from

	# Only set block indent if we gave an indent initally, otherwise use empty string so getVdfSection will ignore indent
	if [ -n "$INDENT" ]; then
		BLOCKINDENT="$(( INDENT + 1 ))"
	else
		BLOCKINDENT=""
	fi

    if [ -z "$BLOCKNAME" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - BLOCKNAME was not provided, skipping..."
        return
    fi

    SEARCHBLOCKVDFSECTION="$( getVdfSection "$SEARCHBLOCK" "" "$INDENT" "$VDF" )"
    if [ -z "$SEARCHBLOCKVDFSECTION" ]; then
		writelog "WARN" "${FUNCNAME[0]} - Could not find VDF section with name '$SEARCHBLOCK' in VDF file '$VDF' -- Skipping"
        return 0
    fi

	# Need to pass Indent + 1 because the block we're searching for is 1 deeper, i.e. searching "CompatToolMapping", the AppID key will be 1 indent deeper
    printf "%s" "$SEARCHBLOCKVDFSECTION" > "/tmp/tmp.vdf"
    getVdfSection "$BLOCKNAME" "" "$BLOCKINDENT" "/tmp/tmp.vdf" | grep -iq "$BLOCKNAME"
}

function getNestedVdfSection {
	VDFPATH="$1"  # i.e. "TopLevel/SecondLevel/ThirdLevel"
	INDENT="$2"  # indent to start searching from
	VDF="$3"

	mapfile -t -d '/' VDFPATHARRAY < <(echo -n "$VDFPATH")
	VDFPATHARRAYLEN="${#VDFPATHARRAY[*]}"
	if [ "$VDFPATHARRAYLEN" -eq 0 ]; then
		writelog "INFO" "${FUNCNAME[0]} - VDFPATHARRY is empty, nothing to do"
		return
	fi
	if [ -z "$INDENT" ]; then
		INDENT="$(( $( guessVdfIndent "${VDFPATHARRAY[0]}" "$VDF" ) ))"
	fi

	# Use getVdfSection on each section it finds until we run out of
	CURRENTSECTION=""
	for SECIND in "${!VDFPATHARRAY[@]}"; do
		SECTIONNAME="$( safequoteVdfBlockName "${VDFPATHARRAY[$SECIND]}" )"
		writelog "INFO" "${FUNCNAME[0]} - Searching for section with name '$SECTIONNAME'"
		NEXTSECTION="$( getVdfSection "$SECTIONNAME" "" "$INDENT" "$VDF" "X" )"
		writelog "INFO" "${FUNCNAME[0]} - NEXTSECTION is '$NEXTSECTION'"
		if [ -n "$NEXTSECTION" ]; then
			CURRENTSECTION="$NEXTSECTION"
			((INDENT+=1))
		else
			writelog "INFO" "${FUNCNAME[0]} - Found no matching section with name '$SECTIONNAME', bailing out"
			break
		fi
	done
	echo "$CURRENTSECTION"
}

## Create entry in given VDF block with matching indentation (Case-INsensitive)
## Appends to bottom of target block by default, but can optionally append to the top instead
##
## This doesn't support adding nested entries, at least not very easily
function createVdfEntry {
    VDF="$1"  # Absolute path to VDF to insert into
    PARENTBLOCKNAME="$( safequoteVdfBlockName "$2" )"  # Block to start from, e.g. "CompatToolMapping"
    NEWBLOCKNAME="$( safequoteVdfBlockName "$3" )"  # Name of new block, e.g. "<AppID>"
    POSITION="${4:-bottom}"  # POSITION to insert into, can be either top/bottom -- Bottom by default
	INDENT="$5"  # Indent that PARENTBLOCKNAME is at (0 = top of file)
	CHECKDUPLICATES="${6:-1}"  # Flag to check for duplicate section names

	# If no indent is given, guess the indent, otherwise use the specified one
	# -------
	# BASETABAMOUNT = Indent for the start of the new section, i.e. one indent in from the parent block
	# BLOCKTABAMOUNT = Indent for the block inside of the section
	#
	# Ex: With CompatToolMapping, BASETABAMOUNT represents the indent for the AppID, such as "22300"
	#                             BLOCKTABAMOUNT represents the indent for the contents of the block under this name
	# -------
	if [ -z "$INDENT" ]; then
		## Calculate indents for new block (one more than PARENTBLOCKNAME indent)
		BASETABAMOUNT="$(( $( guessVdfIndent "${PARENTBLOCKNAME}" "$VDF" ) + 1 ))"
		writelog "INFO" "${FUNCNAME[0]} - Guessed BASETABAMOUNT='${BASETABAMOUNT}'"
	else
		BASETABAMOUNT="$INDENT"
	fi

	# Indents for PARENTBLOCK
	BLOCKTABAMOUNT="$(( BASETABAMOUNT + 1 ))"
	PARENTBLOCKTABAMOUNT="$(( BASETABAMOUNT - 1 ))"

    ## Ensure no duplicates are written out (duplicate names can exist at different indent levels)
    if [ "$CHECKDUPLICATES" -eq 1 ] && checkVdfSectionAlreadyExists "$PARENTBLOCKNAME" "$NEWBLOCKNAME" "$VDF" "$PARENTBLOCKTABAMOUNT"; then
		writelog "SKIP" "${FUNCNAME[0]} - Block '$NEWBLOCKNAME' already exists in parent block '$PARENTBLOCKNAME' - Skipping"
        return
    fi

	writelog "INFO" "${FUNCNAME[0]} - Creating VDF data block to append to '$PARENTBLOCKNAME'"

    ## Create array from args, skip first four to get array of key/value pairs for VDF block
    NEWBLOCKVALUES=("${@:7}")
	writelog "INFO" "${FUNCNAME[0]} - NEWBLOCKVALUES are ${NEWBLOCKVALUES[*]}"

    NEWBLOCKVALUESDELIM="!"

    ## Tab amounts represented as string
    PARENTBLOCKTABSTR="$( generateVdfIndentString "$PARENTBLOCKTABAMOUNT" )"
    BASETABSTR="$( generateVdfIndentString "$BASETABAMOUNT" )"
    BLOCKTABSTR="$( generateVdfIndentString "$BLOCKTABAMOUNT" )"

	writelog "INFO" "${FUNCNAME[0]} - PARENTBLOCKTABAMOUNT is '$PARENTBLOCKTABAMOUNT'"
	writelog "INFO" "${FUNCNAME[0]} - BASETABSTR is '$BASETABSTR'"
	writelog "INFO" "${FUNCNAME[0]} - BLOCKTABSTR is '$BLOCKTABSTR'"

	writelog "INFO" "${FUNCNAME[0]} - Grep is '^${BASETABSTR}${PARENTBLOCKNAME}'"

    ## Calculations for line numbers
    ## PARENTBLOCKLENGTH is 1 line too short
	PARENTBLOCKLENGTH="$( getVdfSection "$PARENTBLOCKNAME" "" "$INDENT" "$VDF" | wc -l )"
	PARENTBLOCKLENGTH="$(( PARENTBLOCKLENGTH + 1 ))"

    BLOCKLINESTART="$( grep -Pin -- "^${PARENTBLOCKTABSTR}${PARENTBLOCKNAME}" "$VDF" | head -n1 | cut -d ':' -f1 | xargs )"
    TOPOFBLOCK="$(( BLOCKLINESTART + 2 ))"
	writelog "INFO" "${FUNCNAME[0]} - BLOCKLINESTART is '$BLOCKLINESTART'"

	# HACK: If parent block indent is -1, we can assume this means we want to add this VDF entry as the LAST block in the file
	#       If we want to add a block to the end of the file, we only need to move up 2 lines (last line is always blank)
	#       But if we're not at the end of the file we can assume we need to move up 3 lines (to account for the block/entry FOLLOWING the block we want to add)
	#
	#      For appending to the end of the VDF file, we want to start appending at the line that has the last closing brace (since the last line is blank, going up 2 lines gives us the line with the ending brace)
	#      For appending in any other case, we assume we have to move up 3 lines
	#
	#     To fix this we assume a default line offset of 3, but if PARENTBLOCKTABAMOUNT is 1, then we set the line offset to 2
	#     These are basically magic numbers discovered by trial and error, and a fix to make the logic more consistent is welcome
	BOTTOMOFBLOCKOFFSET=3
	if [ "$PARENTBLOCKTABAMOUNT" -eq -1 ]; then
		BOTTOMOFBLOCKOFFSET=2
	fi

    BOTTOMOFBLOCK="$(( BLOCKLINESTART + PARENTBLOCKLENGTH - BOTTOMOFBLOCKOFFSET ))"

	writelog "INFO" "${FUNCNAME[0]} - PARENTBLOCKLENGTH is '${PARENTBLOCKLENGTH}' lines"
	writelog "INFO" "${FUNCNAME[0]} - TOPOFBLOCK is line '${TOPOFBLOCK}'"
	writelog "INFO" "${FUNCNAME[0]} - BOTTOMOFBLOCK is line '${BOTTOMOFBLOCK}'"

    ## Decide which line to insert new block into (uses if/else for ease of logging)
    if [[ "${POSITION,,}" == "top" ]]; then
        INSERTLINE="${TOPOFBLOCK}"
		writelog "INFO" "${FUNCNAME[0]} - Will insert new block into top of '$PARENTBLOCKNAME' VDF section"
	else
		INSERTLINE="${BOTTOMOFBLOCK}"
		writelog "INFO" "${FUNCNAME[0]} - Will insert new block into bottom of '$PARENTBLOCKNAME' VDF section"
    fi

    ## Build new VDF entry string
    ## Maybe this could be a separate function at some point, that generates a VDF string from the input array?
    NEWBLOCKSTR="${BASETABSTR}${NEWBLOCKNAME}\n"  # Add tab + block name
    NEWBLOCKSTR+="${BASETABSTR}{\n"  # Add tab + opening brace
    for i in "${NEWBLOCKVALUES[@]}"; do
        ## Cut string in array at delimiter and store them as key/val
        NEWBLOCKDATA_KEY="$( echo "$i" | cut -d "${NEWBLOCKVALUESDELIM}" -f1 )"
        NEWBLOCKDATA_VAL="$( echo "$i" | cut -d "${NEWBLOCKVALUESDELIM}" -f2 )"

        NEWBLOCKDATA_KEY="$( safequoteVdfBlockName "$NEWBLOCKDATA_KEY" )"
        NEWBLOCKDATA_VAL="$( safequoteVdfBlockName "$NEWBLOCKDATA_VAL" )"

        NEWBLOCKSTR+="${BLOCKTABSTR}${NEWBLOCKDATA_KEY}"  # Add tab +  key
        NEWBLOCKSTR+="\t\t${NEWBLOCKDATA_VAL}\n"  # Add tab + val + newline
    done
    NEWBLOCKSTR+="${BASETABSTR}}"  # Add tab + closing brace

	writelog "INFO" "${FUNCNAME[0]} - Generated VDF block string '$NEWBLOCKSTR'"
	writelog "INFO" "${FUNCNAME[0]} - Writing out VDF block string to VDF file at '$VDF'"

	backupVdfFile "$VDF"

    ## Write out new string to calculated line in VDF file
    sed -i "${INSERTLINE}a\\${NEWBLOCKSTR}" "$VDF"
}

## Take in a VDF block and update a property in it, then update the original file with the updated block
## We can use this to update the compatibility tool for an existing VDF block, or update some Non-Steam Game properties
function editVdfSectionValue {
	VDFSECTION="$1"  # VDF section text i.e. from getNestedVdfSection
	VDFPROPERTYNAME="$2"  # i.e. 'OverlayAppEnable'
	VDFPROPERTYVAL="$3"  # i.e. '1'
	VDF="$4"

	VDFPROPERTYORGVAL="$( getVdfSectionValue "$VDFSECTION" "$VDFPROPERTYNAME" | sed 's/[]\/$*.^[]/\\&/g' )"
	VDFPROPERTYNEWVAL="$( createVdfPropertyString "${VDFPROPERTYNAME}" "${VDFPROPERTYVAL}" )"

	# maybe later, PR welcome if you can do this :-)
	#shellcheck disable=SC2001
	UPDATEDVDFSECTION="$( echo "${VDFSECTION}"| sed "s/${VDFPROPERTYORGVAL}/${VDFPROPERTYNEWVAL}/g" )"

	backupVdfFile "$VDF"
	substituteVdfSection "$VDFSECTION" "$UPDATEDVDFSECTION" "$VDF"
}

## Add a single value to bottom of a given VDF section
function addVdfSectionValue {
	VDFSECTION="$1"
	VDFPROPERTYNAME="$2"
	VDFPROPERTYVAL="$3"
	VDF="$4"

	VDFSECTIONEND="$( echo "$VDFSECTION" | tail -n1 )"
	VDFSECTIONENDLINE="$( echo "$VDFSECTION" | grep -in "$VDFSECTIONEND" | cut -d ':' -f1 )"
	VDFSECTIONINSERTLINE="$(( VDFSECTIONENDLINE - 1 ))"

	VDFSECTIONENDINDENTAMT="$( echo "$VDFSECTIONEND" | awk '{print gsub(/\t/,"")}' )"
	VDFPROPERTYINDENT="$( generateVdfIndentString "$(( VDFSECTIONENDINDENTAMT + 1 ))" "" )"

	VDFPROPERTY="${VDFPROPERTYINDENT}$( createVdfPropertyString "$VDFPROPERTYNAME" "$VDFPROPERTYVAL" )"
	UPDATEDVDFSECTION="$( echo "$VDFSECTION" | sed "${VDFSECTIONINSERTLINE}a\\${VDFPROPERTY}" )"

	substituteVdfSection "$VDFSECTION" "$UPDATEDVDFSECTION" "$VDF"
}

## Use parameter expansion to replace old block with new block in VDF file
## Thanks to StackOverflow for this answer, though was noted this may break down if the file exceeds 1mb -- Should work for us though
function substituteVdfSection {
	VDFOLDSECTION="$1"
	VDFNEWSECTION="$2"
	VDF="$3"

	VDFCONTENTS="$( cat "$VDF" )"
	UPDATEDVDFCONTENTS="${VDFCONTENTS//"$VDFOLDSECTION"/"$VDFNEWSECTION"}"
	printf "%s\n" "$UPDATEDVDFCONTENTS" > "$VDF"
}

## Extract value from text-based VDF block
## ex: "ExampleProperty"		"ex-val"
function getVdfSectionValue {
	VDFSECTION="$1"  # VDF section text i.e. from getNestedVdfSection
	VDFPROPERTYNAME="$2"  # i.e. 'OverlayAppEnable'
	ONLYVALUE="$3"

	VDFVAL="$( trimWhitespaces "$(echo "${VDFSECTION}" | grep "${VDFPROPERTYNAME}")" )"
	if [ -n "$ONLYVALUE" ]; then
		echo "$VDFVAL" | cut -f3
	else
		echo "$VDFVAL"
	fi
}

## Return a VDF property string
function createVdfPropertyString {
	if jq -e '.' 1>/dev/null 2>&1 <<<"$2"; then
		writelog "INFO" "${FUNCNAME[0]} - Looks like our input string '$2' is JSON -- Creating JSON VDF Property"
		printf "%s\t\t%s" "$( safequoteVdfBlockName "$1" )" "$( prepareJSONVdfProperty "$2" )"  # Don't use safequote on JSON string
	else
		writelog "INFO" "${FUNCNAME[0]} - Generating normal VDF property string for '$1: $2'"
		printf "%s\t\t%s" "$( safequoteVdfBlockName "$1" )" "$( safequoteVdfBlockName "$2" )"
	fi
}

## Format a JSON entry by double-escaping it and removing any surrounding quotes so that it can be written out into the VDF correctly
## i.e. turn "\"{\\\"foo\\\": \\\"bar\\\"}\"" -> \"{\\\"foo\\\": \\\"bar\\\"}\"
function prepareJSONVdfProperty {
	SANITISEDVDFJSON="$( jq '. | tojson | tojson' <<< "$1" )"
	SANITISEDVDFJSON="${SANITISEDVDFJSON#\"}"  # Remove any plain quote from start
	echo "${SANITISEDVDFJSON%\"}"  # Remove any plain quote from end
}

## Get the internal name of the compatibility tool selected for all titles from the Steam Client Compatibility settings
## ex: Proton 8.0-3 would return 'proton_8'
##
## Compatibility Tools, even ones that are Windows EXEs, are not given a compatibility tool by default, so this function can be used
## to select the one used by default for Windows games.
##
## This compatibility tool doesn't even have to be Proton.
