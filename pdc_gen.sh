#!/bin/bash - 
#===============================================================================
#         USAGE: ./pdc_gen.sh --help
# 
#   DESCRIPTION: RTFM (--help)
#  REQUIREMENTS: find, xargs, sed, pandoc
#        AUTHOR: Sylvain S. (ResponSyS), mail@systemicresponse.com
#       CREATED: 11/27/2017 16:07
#===============================================================================
#===============================================================================
# VARIABLES
#===============================================================================
# Root path for searching files
SEARCH_PATH=
# Name of new converted files (without the extension); if unset, new files will 
# have the same filename
FNAME_NEW=
# Extension of input files
EXT_IN="pdc"
# List of output files extensions
EXT_OUT="pdf"
# Number of simultaneous conversions (through `xargs -P${JOBS}`)
JOBS=4
# Pandoc additional arguments (--template, etc.)
PANDOC_ARGS="--fail-if-warnings"

#===============================================================================
# SCRIPT
#===============================================================================
#
# TODO: avoid bash aliases by executing `which find` instead of `find` etc.
# TODO: --no-interactive option to deactive xargs '-p' flag
# TODO: implement FNAME_NEW functionality
# TODO: better doc commenting
# TODO: improve verbose on dry-run
#
# Set debug parameters
[[ $DEBUG ]] && set -o nounset
set -o errexit -o pipefail

SCRIPT_NAME="${0##*/}"
VERSION=0.5

# Format characters
FMT_BOLD='\e[1m'
FMT_UNDERL='\e[4m'
FMT_OFF='\e[0m'
# Error codes
ERR_WRONG_ARG=2
ERR_NO_FILE=127

# TODO: turn the variable mess into one array (XARGS_FLAGS)
XARGS_FLAGS=
XARGS_JOBS="-P${JOBS}"
XARGS_PROMPT=
# Number of arguments for pandoc invocation via xargs
XARGS_CMD_COUNT=
DRY_RUN=
RET=

# Test if a file exists (dir or not)
# $1: path to file (string)
fn_need_file() {
	[[ -e "$1" ]] || fn_exit_err "need '$1' (file not found)" $ERR_NO_FILE
}
# Test if a dir exists
# $1: path to dir (string)
fn_need_dir() {
	[[ -d "$1" ]] || fn_exit_err "need '$1' (directory not found)" $ERR_NO_FILE
}
# Test if a command exists
# $1: command (string)
fn_need_cmd() {
	command -v "$1" > /dev/null 2>&1
	[[ $? -eq 0 ]] || fn_exit_err "need '$1' (command not found)" $ERR_NO_FILE
}
# $1: message (string)
m_say() {
	echo -e "$SCRIPT_NAME: $1"
}
# Exit with message and provided error code
# $1: error message (string), $2: return code (int)
fn_exit_err() {
	m_say "${FMT_BOLD}ERROR${FMT_OFF}: $1" >&2
	exit $2
}
# Print help
fn_show_help() {
    cat << EOF
$SCRIPT_NAME 0.5
    Recursively convert files with 'pandoc' (ideal for automation).
    Turn all matching **.EXT_IN files into **.EXT_OUT.
USAGE
    $SCRIPT_NAME [OPTIONS] SEARCH_PATH
	where SEARCH_PATH is the path under which all files will be searched 
OPTIONS
    -i EXT_IN           set extension of input files (default: "$EXT_IN")
    -o EXT_OUT          set extension(s) of output files; EXT_OUT is a 
                         ':'-separated list of extensions (default: "$EXT_OUT")
    -n FNAME            if set, change filenames of converted files to 
                         FNAME.EXT_OUT (default: "$FNAME_NEW")
    -j JOBS             set the number of simultaneous conversions
                         (default: $JOBS)
    -p, --interactive   prompt the user about whether to run each command line
    --dry-run           output command lines without executing them
    -a PANDOC_ARGS      set additional arguments to 'pandoc' invocation
                         (default: "$PANDOC_ARGS")
AUTOMATION WITH VARIABLES
    To automate the behaviour of the script without having to specify the same 
     arguments each time, edit the default global variables values under the 
     VARIABLES section at the top of this script ($SCRIPT_NAME). Then, see 
     '$SCRIPT_NAME --help' to make sure the default values are correct.
EXAMPLE
    $ ./$SCRIPT_NAME . -j 4 -n index -i pdc -o "html:pdf" -a "--template ./tmpl.pandoc"
	Convert all files ending with ".pdc" found under ./ to (1) "index.html" 
         and (2) "index.pdf" files in their respective directory with the pandoc
         template "./tmpl.pandoc"
AUTHOR
    Written by Sylvain Saubier (<http://SystemicResponse.com>)
REPORTING BUGS
    Mail at: <feedback@systemicresponse.com>
EOF
}

fn_print_params() {
	cat 1>&2 << EOF
EXT_IN         $EXT_IN
EXT_OUT        $EXT_OUT
JOBS           $JOBS
FNAME_NEW      $FNAME_NEW
SEARCH_PATH    $SEARCH_PATH
XARGS_FLAGS    $XARGS_FLAGS
PANDOC_ARGS    $PANDOC_ARGS
EOF
}

# Count number of arguments for pandoc invocation via xargs
fn_count_args() {
	XARGS_CMD_COUNT=0
	local PANDOC_ARGS_MODEL="$PANDOC_ARGS --resource-path=PATH IN -o OUT"
	for arg in $PANDOC_ARGS_MODEL; do
		# (( XARGS_CMD_COUNT++ )) returns 1 when XCC==0, which causes script to exit on `set -o errexit`
		(( ++XARGS_CMD_COUNT ))
	done
	[[ $DEBUG ]] && echo "Number of pandoc arguments for xargs: $XARGS_CMD_COUNT"
}
# Ensure recent enough 'pandoc' version
# TODO: better version check
fn_check_pandoc_ver() {
	pandoc --version | grep "pandoc 2[.]" > /dev/null || fn_exit_err "need pandoc version 2" $ERR_WRONG_ARG
}

# return: result of 'find' invocation (string)
fn_find_files() {
	# Defaults to FNAME_NEW if set
	local FNAME_OUT="${FNAME_NEW:-%p}"
	# <EXTOUT> is placeholder for extension of output files
	RET="$(find $SEARCH_PATH -type f -name \*[.]${EXT_IN} -printf "$PANDOC_ARGS --resource-path='%h' '%p' -o '$FNAME_OUT.<EXTOUT>'\n")"
	[[ $DEBUG ]] && echo -e "FIND list:\n$RET"
}

# $1: list of files to convert, '\n'-separated (string)
fn_gen_files() {
	# xargs can handle whitespaces in filenames (god knows how but it does)
	local CMD="pandoc"
	[[ $DRY_RUN ]] && XARGS_PROMPT= && CMD=(echo pandoc)
	IFS=':'
	for EXT in $EXT_OUT; do
		echo "$1" | sort | uniq | sed "s/[.]$EXT_IN[.]<EXTOUT>/.$EXT/" | 
			xargs -n${XARGS_CMD_COUNT} -r $XARGS_FLAGS $XARGS_JOBS $XARGS_PROMPT ${CMD[@]}
	done
}

main() {
	fn_need_cmd "pandoc"
	fn_check_pandoc_ver
	fn_need_cmd "sed"
	fn_need_cmd "find"
	fn_need_cmd "xargs"
	fn_need_cmd "sort"
	fn_need_cmd "uniq"
	fn_need_cmd "grep"

	# PARSE ARGUMENTS
	[[ $# -eq 0 ]] && {
		fn_show_help
		exit
	}
	while [[ $# -ge 1 ]]; do
		case "$1" in
			"-n")
				[[ $2 ]] || fn_exit_err "missing argument to '-n'" $ERR_WRONG_ARG
				shift
				FNAME_NEW="$1"
				;;
			"-i")
				[[ $2 ]] || fn_exit_err "missing argument to '-i'" $ERR_WRONG_ARG
				shift
				EXT_IN="$1"
				;;
			"-o")
				[[ $2 ]] || fn_exit_err "missing argument to '-o'" $ERR_WRONG_ARG
				shift
				EXT_OUT="$1"
				;;
			"-j")
				[[ $2 ]] || fn_exit_err "missing argument to '-j'" $ERR_WRONG_ARG
				shift
				XARGS_JOBS="-P${1}"
				;;
			"--interactive"|"-p")
				XARGS_PROMPT=$1
				;;
			"--dry-run")
				DRY_RUN=1
				;;
			"-a")
				[[ $2 ]] || fn_exit_err "missing argument to '-a'" $ERR_WRONG_ARG
				shift
				PANDOC_ARGS="$1"
				;;
			"-h"|"--help")
				fn_show_help
				exit
				;;
			*)
				# adds arg to search pathes
				SEARCH_PATH="$SEARCH_PATH $1"
				;;
		esac	# --- end of case ---
		# Delete $1
		shift
	done

	for FILE in $SEARCH_PATH ; do
		fn_need_file "$FILE"
	done

	[[ "$EXT_IN" ]]  || fn_exit_err "EXT_IN not set" $ERR_WRONG_ARG
	[[ "$EXT_OUT" ]] || fn_exit_err "EXT_OUT not set" $ERR_WRONG_ARG

	[[ "$DEBUG" ]] && fn_print_params

	m_say "searching for files to convert..."
	fn_find_files
	[[ -z "$RET" ]] && fn_exit_err "no file was found matching your criterias" $ERR_NO_FILE
	m_say "converting..."
	fn_count_args
	fn_gen_files "$RET"
	m_say "done!"
}

main "$@"
