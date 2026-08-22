#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

### default vars ###

if [ -z "$XDG_CONFIG_HOME" ]; then
	STLCFGDIR="$HOME/.config/${PROGNAME,,}"													# either hardcoded config dir
else
	STLCFGDIR="$XDG_CONFIG_HOME/${PROGNAME,,}"												# or in XDG_CONFIG_HOME if the user set the variable
fi

SYSTEMSTLCFGDIR="$PREFIX/share/${PROGNAME,,}"												# systemwide config dir
BASELOGDIR="$STLCFGDIR/logs"																# base logfile dir
DEFLOGDIR="$BASELOGDIR/${PROGNAME,,}"																# default logfile dir

if [ -z "$LOGDIR" ]; then
	LOGDIR="$DEFLOGDIR"
fi

LOGDIRID="$LOGDIR/id"

LOGDIRTI="$LOGDIR/title"
STLPROTONLOGDIR="$BASELOGDIR/proton"
STLPROTONIDLOGDIR="$STLPROTONLOGDIR/id"
STLPROTONTILOGDIR="$STLPROTONLOGDIR/title"
STLDXVKLOGDIR="$BASELOGDIR/dxvk"
STLWINELOGDIR="$BASELOGDIR/wine"
STLVKD3DLOGDIR="$BASELOGDIR/vkd3d"
STLGLLOGDIR="$BASELOGDIR/gamelaunch"
STLGLLOGDIRID="$STLGLLOGDIR/id"
STLGLLOGDIRTI="$STLGLLOGDIR/title"
PLAYTIMELOGDIR="$BASELOGDIR/playtime"
STLGAMEDIR="$STLCFGDIR/gamecfgs"
STLGUIDIR="$STLCFGDIR/guicfgs"
STLGAMEDIRID="$STLGAMEDIR/id"
STLCUSTVARSDIR="$STLGAMEDIR/customvars"
STLGAMEDIRTI="$STLGAMEDIR/title"
STLCOLLECTIONDIR="$STLCFGDIR/collections"
STLREGDIR="$STLCFGDIR/regs"
STLDLDIR="$STLCFGDIR/downloads"
STLBACKDIR="$STLCFGDIR/backup"
BACKEX="$STLBACKDIR/exclude"
HIDEDIR="$STLCFGDIR/hide"
STLTEMPDIR="$STLCFGDIR/temp"
CODA="compatdata"
STLCOMPDAT="$STLCFGDIR/$CODA"
METADIR="$STLCFGDIR/meta"
GEMETA="$METADIR/id/general"
CUMETA="$METADIR/id/custom"
EVMETAID="$METADIR/eval/id"
EVMETASKIPID="$EVMETAID/skip"
EVMETACUSTOMID="$EVMETAID/custom"
EVMETAADDONID="$EVMETAID/addon"
EVMETATITLE="$METADIR/eval/title"
EVMETAOLD="$METADIR/eval/old"
EVALSC="evaluatorscript"
GECUST="get-current-step"
ISCRI="iscriptevaluator"
LIINPA="linux_install_path"
STEWOS="Steamworks Shared"
LECO="legacycompat"
FRSTATE="$STLSHM/firuState.txt"
TIGEMETA="$METADIR/title/general"
TICUMETA="$METADIR/title/custom"
DRC="drive_c"
DRCU="$DRC/users"
STUS="steamuser"
PUBUS="Public"
SUBADIR="$STLBACKDIR/$STUS"
SUBADIRID="$SUBADIR/id"
SUBADIRTI="$SUBADIR/title"
RSSUB="reshade-shaders"
WTDLDIR="$STLDLDIR/winetricks"
DLWT="$WTDLDIR/src/winetricks"
STLSHADDIR="$STLDLDIR/shaders"
SHADREPOLIST="$STLSHADDIR/repolist.txt"
SHADERREPOBLOCKLIST="$STLSHADDIR/repoblocklist.txt"
TWEAKDIR="$STLCFGDIR/tweaks"																# the parent directory for all user tweakfiles
USERTWEAKDIR="$TWEAKDIR/user"																# the place for the users own main tweakfiles
TWEAKCMDDIR="$TWEAKDIR/cmd"																	# dir for scriptfiles used by tweakfiles
SBSTWEAKDIR="$TWEAKDIR/sbs"																	# directory for optional config overrides for easier side-by-side VR gaming
MO2DLDIR="$STLDLDIR/mo2"
HMMDLDIR="$STLDLDIR/hedgemodmanager"
HMMVERFILE="$HMMDLDIR/hmmver.txt"
CONTYDLDIR="$STLDLDIR/conty"
X64DBGDLDIR="$STLDLDIR/$X64D"
GEOELFDLDIR="$STLDLDIR/geo11"
WDIBDLDIR="$STLDLDIR/${WDIB}"
EWDIB="${WDIB//-}"
RUNWDIB="$WDIBDLDIR/${EWDIB}.exe"
LGEOELFSYM="$GEOELFDLDIR/latest"
CUSTOMFALLBACKPIC="$STLDLDIR/custom-fallback.png"
VTX="vortex"
VOGAT="${VTX}games.txt"
STLVORTEXDIR="$STLCFGDIR/$VTX"
VORTEXDLDIR="$STLDLDIR/$VTX"
VORTSETCMD="$STLSHM/vortset.cmd"
VTST="$STLSHM/vsetup.txt"
SPEK="SpecialK"
SPEKDLDIR="$STLDLDIR/${SPEK,,}"
FWS="FlawlessWidescreen"
FWSDLDIR="$STLDLDIR/${FWS,,}"
YADAIDLDIR="$STLDLDIR/yadappimage"
DOTN="dotnet"
MO2="mo2"
STLMO2DIR="$STLCFGDIR/$MO2"
STLMO2DLDATDIR="$STLMO2DIR/dldata"
MO="ModOrganizer"
HMM="HedgeModManager"
HMMNICE="Hedge Mod Manager"
HMMSTABLE="stable"
HMMDEV="nightly"
HMMAUTO="auto"
HMMDF="$HMM-${PROGNAME,,}.desktop"
HMMDFDL="$HMM-${PROGNAME,,}-dl.desktop"
HMMDFPA="$HOME/.local/share/applications/$HMMDF"
HMMDFDLPA="$HOME/.local/share/applications/$HMMDFDL"
MORDIR="$DRC/Modding"
MOERDIR="$MORDIR/MO2"
MOERPATH="$MOERDIR/${MO}.exe"
STLHMMDIR="$STLCFGDIR/${HMM,,}"
DOCS="Documents"
MYDOCS="My $DOCS"
MYGAMES="My Games"
PLACEHOLDERAID="31337"
PLACEHOLDERGN="Placeholder"
DPRS="Depressurizer"
DPRSDLDIR="$STLDLDIR/${DPRS,}"
DEPS="Dependencies"
DEPSGE="${DEPS}Gui.exe"
DEPSDLDIR="$STLDLDIR/${DEPS,}"
DEPSLATDIR="$DEPSDLDIR/latest"
DEPSL64="$DEPSLATDIR/64/$DEPSGE"
DEPSL32="$DEPSLATDIR/32/$DEPSGE"
MAHU="mangohud"
MANGOAPP="mangoapp"
MAHUCFGDIR="$STLCFGDIR/$MAHU"
MAHUCID="$MAHUCFGDIR/id"
MAHUCTI="$MAHUCFGDIR/title"
MAHUTMPL="$MAHUCFGDIR/$MAHU-${PROGNAME,,}-template.conf"
MAHULOGDIR="$BASELOGDIR/$MAHU"
MAHULID="$MAHULOGDIR/id"
MAHULTI="$MAHULOGDIR/title"
PFX86="Program Files (x86)"
PFX86S="$PFX86/Steam"
APIN="appinfo"
SLO="Steam Launch Option"
SOMEPOPULARWINEPAKS="dotnet4 quartz xact"
SOMEWINEDEBUGOPTIONS="-all,+steam,+vrclient,+vulkan"
DEFSGDBHERODIMS="3840x1240,1920x620"
DEFSGDBBOXARTDIMS="600x900"
DEFSGDBTENFOOTDIMS="920x430,460x215"
SGDBHASFILEOPTS="skip!backup!replace"
SGDBTYPEOPTS="static!animated!static,animated!animated,static"
SGDBTAGOPTS="any!true!false"
SGDBHEROSTYLEOPTS="alternate,blurred,material"
SGDBLOGOSTYLEOPTS="official,white,black,custom"
SGDBGRIDSTYLEOPTS="alternate,blurred,white_logo,material,no_logo"
SGDBTNFTSTYLEOPTS="alternate,blurred,white_logo,material"
GETSTAID="99[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]99"

STLGAMES="$STLCFGDIR/games"
STLSTEAMDECKLASTVERS="$STLCFGDIR/lastvers"
STLGDESKD="$STLGAMES/desktop"
STLIDFD="$STLGAMES/desktopfiles"
STLISLDFD="$STLGAMES/sldesktopfiles"
STLAPPINFOIDDIR="$STLGAMES/$APIN"
STLGHEADD="$STLGAMES/header"
STLGSAD="$STLGAMES/standalone"
STLGICONS="$STLGAMES/icons"
STLGDECKCOMPAT="$STLGAMES/deckinfo"
STLGICO="$STLGICONS/ico"
STLGZIP="$STLGICONS/zip"
STLGPNG="$STLGICONS/png"
STLGSAPD="$STLGSAD/titles"
STLGSACD="$STLGSAD/$CODA"
STLGPEVKD="$STLGAMES/pev"
MO2INSTFAIL="$STLSHM/${MO}-failed.txt"
ABSGAMEEXEPATH="$NON"
GEOELF="geo-11"
ISORIGIN=0

#STLGSCPTD="$STLGAMES/scripts"
NOGAMES=",70_2260196511,228980,858280,961940,1054830,1070560,1113280,1245040,1391110,1420170,"
# Taken from GE-Proton7-24 changelog, removing some duplicates
WINE_FSR_CUSTOM_RESOLUTIONS=(
	# 1080p
	"960x540"
	"1129x635"
	"1280x720"
	"1477x831"

	# 2K
	"1506x847"
	"1706x960"
	"1970x1108"

	# Ultra-Wide
	"1720x720"
	"2024x847"
	"2293x960"
	"2646x1108"

	# 4K
	"1920x1080"
	"2259x1270"
	"2560x1440"
	"2954x1662"

	# 32:9 (5120x1440) -- Samsung Neo G9
	"2560x720"
	"3012x847"
	"3413x960"
	"3839x1108"
)

# Hex patterns for various blocks in shortcuts.vdf that we can grep for -- Casing matters!
SHORTCUTVDFFILESTARTHEXPAT="0073686f7274637574730000300002"  # Bytes for beginning of the shortcuts.vdf file
SHORTCUTVDFENTRYBEGINHEXPAT="00080800.*?0002"  # Pattern for beginning of shortcut entry in shortcuts.vdf -- Beginning of file has a different pattern, but every other pattern begins like this
SHORTCUTSVDFENTRYENDHEXPAT="000808"  # Pattern for how shortcuts.vdf blocks end
SHORTCUTVDFAPPIDHEXPAT="617070696400"  # 'appid'
SHORTCUTVDFNAMEHEXPAT="(014170704e616d6500|6170706e616d6500)"  # 'AppName' and 'appname'
SHORTCUTVDFEXEHEXPAT="000145786500"  # 'Exe' ('exe' is 6578650a if we ever need it)
SHORTCUTVDFSTARTDIRHEXPAT="0001537461727444697200"  # 'StartDir'
SHORTCUTVDFICONHEXPAT="000169636f6e00"  # 'icon'
SHORTCUTVDFENDPAT="0001"  # Generic end pattern for each shortcut.vdf column

function setGNID {
	# only keep alphabet chars
	INGN="$(tr -cd '[:alnum:]' <<< "${1^^}")"
	INGN="${INGN//[[:digit:]]/}"
	MIDNUMSIZE=$((STLAIDSIZE -4))

	if [ "${#INGN}" -gt "$MIDNUMSIZE" ]; then
		INGN="${INGN:0:MIDNUMSIZE}"
	fi

	while [ "${#INGN}" -lt "$MIDNUMSIZE" ]; do
		INGN="${INGN}A"
	done

	ALPHARR=(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z)

	function numberOut {
		for n in "${!ALPHARR[@]}"; do
			if [ "${ALPHARR[$n]}" == "$1" ]; then
				NUM="$((n +1))"
				if [ "$NUM" -gt 9 ]; then
					printf "%s" "${NUM:1:1}"
				else
					printf "%s" "${NUM:0:1}"
				fi
			fi
		done
	}

	function outNum {
		i=0
		while [ "$i" -lt "${#1}" ]; do
			numberOut "${1:$i:1}"
			i=$((i+1))
		done
		printf "\n"
	}

	MIDNUM="$(outNum "$INGN")"
	echo "99${MIDNUM}99"
}

function initAID {
	STLPLAY=0
	if [ -n "$STEAM_COMPAT_APP_ID" ]; then
		AID="$STEAM_COMPAT_APP_ID"
		writelog "INFO" "${FUNCNAME[0]} - Set AID from STEAM_COMPAT_APP_ID to '$AID'" "P"
	fi

	if [ -z "$AID" ] || [ "$AID" -eq "0" ]; then
		# shellcheck disable=SC2154		# SteamAppId comes from Steam
		if [ -z "$SteamAppId" ]; then
			if grep -q "^play" <<< "$@" && [ -n "$2" ] && [ -z "$3" ] && [ "$2" != "gui" ] && [ "$2" != "ed" ]; then
				STLPLAY=1
				if [ "$2" -eq "$2" ] 2>/dev/null ; then
					AID="$2"
				elif [ -f "$2" ]; then
					GN="${2##*/}"
					AID="$(setGNID "$GN")"
				fi
				writelog "INFO" "${FUNCNAME[0]} - Set AID to '$PROGCMD' ID '$AID'" "P"
			elif grep -q "^play" <<< "$@" && [ -f "$3" ]; then
				STLPLAY=1
				GN="${3##*/}"
				AID="$2"

				writelog "INFO" "${FUNCNAME[0]} - Set AID to '$PROGCMD' ID '$AID'" "P"
			else
				AID="$PLACEHOLDERAID"
				writelog "INFO" "${FUNCNAME[0]} - Set AID to PLACEHOLDERAID '$AID'" "P"
			fi
		else
			if [ "$SteamAppId" -eq "0" ]; then
				AID="${STEAM_COMPAT_DATA_PATH##*/}"
				writelog "INFO" "${FUNCNAME[0]} - Set AID from STEAM_COMPAT_DATA_PATH '$STEAM_COMPAT_DATA_PATH' to '${STEAM_COMPAT_DATA_PATH##*/}', because SteamAppId is '$SteamAppId'" "P"
			else
				AID="$SteamAppId"
				writelog "INFO" "${FUNCNAME[0]} - Set AID to SteamAppId '$SteamAppId' coming from Steam" "P"
			fi
		fi
	fi

	if [ -n "$STEAM_COMPAT_DATA_PATH" ]; then
		OSCDP="$STEAM_COMPAT_DATA_PATH"
		writelog "INFO" "${FUNCNAME[0]} - Set OSCDP to STEAM_COMPAT_DATA_PATH '$STEAM_COMPAT_DATA_PATH'" "P"
	fi
}

STLFAVMENUCFG="$STLCFGDIR/$FACO"															# optional config (in fact just a list with variables) which holds all entries for the individual favorites menu
STLMENUSORTCFG="$STLCFGDIR/$MENSO"															# holds the category sort order for all menus
STLMENUBLOCKCFG="$STLCFGDIR/$MENUBLOCK"
#STARTEDITORCFGLIST
STLDEFGLOBALCFG="$STLCFGDIR/global.conf"													# global config
STLDEFGAMECFG="$STLCFGDIR/default_template.conf"											# the default config template used to create new per game configs - will be auto created if not found
GLOBCUSTVARS="$STLCUSTVARSDIR/global-custom-vars.conf"										# global config file for user defined custom variables

function setSDCfg {
STLSDLCFG="$STLCFGDIR/steamdeck.conf"														# Steam Deck config
}

function setAIDCfgs {
STLGAMECFG="$STLGAMEDIRID/$AID.conf"														# the game specific config file which is used by the launched game - created from $STLDEFGAMECFG if not found
TWEAKCFG="$USERTWEAKDIR/$AID.conf"															# the game specific shareable config tweak overrides
SBSTWEAKCFG="$SBSTWEAKDIR/$AID.conf"														# the game specific shareable config sbs tweak overrides
LOGFILE="$LOGDIRID/$AID.log"
GAMECUSTVARS="$STLCUSTVARSDIR/$AID.conf"													# game specific config file for user defined custom variables
}

STLURLCFG="$STLCFGDIR/url.conf"																# url config
CUSTOMPROTONLIST="$STLCFGDIR/protonlist.txt"												# plain textfile with additional user proton versions
VORTEXSTAGELIST="$STLVORTEXDIR/stages.txt"													# plain textfile with Vortex Stage directories - one per Steam Library partition
SEENVORTEXGAMES="$STLVORTEXDIR/$CODA/seen$VOGAT"
EXGLOB="$BACKEX/exclude-global.txt"
#ENDEDITORCFGLIST

STLLANGDIR="$STLCFGDIR/lang"
STLDEFLANG="english"

STLDXVKDIR="$STLCFGDIR/dxvk"																# base dxvk config dir from where default per game configs are automatically parsed
ISGAME=0																					# 1=game was launched, 2=windows game, 3=linux game
WFEAR="waitforexitandrun"
SA="steamapps"
SAC="$SA/common"
L2EA="link2ea"
CTD="compatibilitytools.d"
SLR="SteamLinuxRuntime"
STERU="steam-runtime"
BIWI="bin/wine"
DBW="dist/$BIWI"
FBW="files/$BIWI"
STLPROTDIR="$STLCFGDIR/proton"
STLPROTCOMPDATDIR="$STLPROTDIR/$CODA"
STLPROTSTUSDIR="$STLPROTDIR/$STUS"
STLPROTPUBUSDIR="$STLPROTDIR/$PUBUS"
STLEARLYPROTCONF="$STLPROTDIR/earlyproton.conf"
PROCU="proton/custom"
CTVDF="compatibilitytool.vdf"
TOMA="toolmanifest.vdf"
LIFOVDF="libraryfolders.vdf"
SCV="sharedconfig.vdf"
AIVDF="$APIN.vdf"
AITXT="$APIN.txt"
AAVDF="appcache/$AIVDF"
APVDF="appcache/packageinfo.vdf"
USDA="userdata"
SCVDF="shortcuts.vdf"
SRSCV="7/remote/$SCV"
LCV="localconfig.vdf"
COCOV="config/config.vdf"
LUCOV="config/loginusers.vdf"
SCSHVDF="screenshots.vdf"
SCRSH="760/$SCSHVDF"
LASTRUN="$LOGDIR/lastrun.txt"
SAIT="steam_appid.txt"
DXGI="dxgi.dll"
D3D9="d3d9.dll"
D3D11="d3d11.dll"
D3D47="d3dcompiler_47.dll"
OGL32="opengl32.dll"
AUTO="auto"
D3D47DLDIR="$STLDLDIR/${D3D47%.*}"
SPEKDLLNAMELIST="$AUTO!$DXGI!$D3D9!$D3D11!$OGL32"
RESHADEDLLNAMELIST="$DXGI!$D3D9!$D3D11!$OGL32!$DXGI,$D3D9"
SOMEWINEDLLOVERRIDES="dinput8=n,b!dxgi=n,b!d3d9=n,b!${D3D47//.dll}=n,b!xaudio2_7=n,b"
RS_DX_DEST="$DXGI"
RS_D9_DEST="$D3D9"
RESH="ReShade"
RSSU="${RESH}_Setup"
RSINI="${RESH}.ini"
RSTXT="${RESH}.txt"
IGCS="IGCSInjector"
UUU="UniversalUE4Unlocker"
LFM="launchFavMenu"
LGAM="launchGameMenu"
LGATM="launchGameTemplateMenu"
LGLM="launchGlobalMenu"
LCM="launchCategoryMenu"
HEADLINEFONT="larger"
FONTSIZES="!xx-small!x-small!small!smaller!medium!large!larger!!x-large!xx-large!"
SREG="system.reg"
NSGA="non-steam game"
FSGDBA="FetchSteamGridDBArtwork"
SGA="set game artwork"
BTVP="$DRC/Program Files/Black Tree Gaming Ltd/${VTX^}"
VTXRAA="resources/app.asar"
RABP="${VTXRAA}.unpacked/bundledPlugins"

# make SC happy:
GUI_CUSTOMCMD=""
################

