#!/bin/bash - 
#===============================================================================
#         USAGE: ./pdc_gen.sh --help
# 
#   DESCRIPTION: 
#  REQUIREMENTS: find, xargs, sed, pandoc
#        AUTHOR: Sylvain S. (ResponSyS), mail@systemicresponse.com
#       CREATED: 11/27/2017 16:07
#===============================================================================
#===============================================================================
# VARIABLES
#===============================================================================
# Root path for searching files
SEARCH_PATH=
# Name of new converted files (without the extension); if unset, new files will have the same filename
FNAME_NEW=""
# Extension of input files
EXT_IN="pdc"
# Extension of output files
EXT_OUT="pdf"
# Number of simultaneous conversions (through `xargs -P${JOBS}`)
JOBS=4
# Pandoc additional arguments (--template, etc.)
PANDOC_ARGS="--fail-if-warnings"

#===============================================================================
# SCRIPT
#===============================================================================
#
# TODO: --no-interactive option to deactive xargs '-p' flag
# TODO: implement FNAME_NEW functionality
#
# Set debug parameters
[[ $DEBUG ]] && set -o nounset -o errexit -o pipefail

SCRIPT_NAME="${0##*/}"
VERSION=0.5

# Format characters
FMT_BOLD='\e[1m'
FMT_UNDERL='\e[4m'
FMT_OFF='\e[0m'
# Error codes
ERR_WRONG_ARG=2
ERR_NO_FILE=127

XARGS_FLAGS="-p"

# Test if a file exists (dir or not)
# path to file to test (string)
fn_need_file() {
	[ -e "$1" ] || fn_exit_err "need '$1' (file not found)" $ERR_NO_FILE
}
# Test if a dir exists
# path to dir to test (string)
fn_need_dir() {
	[ -d "$1" ] || fn_exit_err "need '$1' (directory not found)" $ERR_NO_FILE
}
# Test if a command exists
# command (string)
fn_need_cmd() {
	command -v "$1" > /dev/null 2>&1
	[ $? -eq 0 ] ||	fn_exit_err "need '$1' (command not found)" $ERR_NO_FILE
}
# message (string)
m_say() {
	echo -e "$SCRIPT_NAME: $1"
}
# Exit with message and provided error code
# error message (string), return code (int)
fn_exit_err() {
	m_say "${FMT_BOLD}ERROR${FMT_OFF}: $1" >&2
	exit $2
}
# Print help
fn_show_help() {
    cat << EOF
$SCRIPT_NAME 0.5
    Recursively converts all *.EXT_IN files to *.EXT_OUT files using 'pandoc'.

USAGE
    $SCRIPT_NAME [OPTIONS] SEARCH_PATH
	where SEARCH_PATH is the path under which all files will be searched 

OPTIONS
    -i EXT_IN           set extension of input files (default: "$EXT_IN")
    -o EXT_OUT          set extension of output files (default: "$EXT_OUT")
    -n FNAME            if set, change filenames of converted files to 
                        FNAME.EXT_OUT (default: "$FNAME_NEW")
    -j JOBS             set the number of simultaneous conversions
                        (default: $JOBS)
    -a PANDOC_ARGS      set additional arguments to 'pandoc'
                        (default: "$PANDOC_ARGS")

EXAMPLE
    $ ./$SCRIPT_NAME . -j 4 -n index -i pdc -o html -a "--template ./tmpl.pandoc"
	Convert all files ending with ".pdc" found under ./ to "index.html"
        files in their current directory with the pandoc template "./tmpl.pandoc"

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

fn_gen_files() {
	# whitespaces hopefully escaped with \"
	# TODO: implement FNAME_NEW functionality
	find $SEARCH_PATH -type f -name "*[.]${EXT_IN}" | sort | uniq | sed "s/[.]$EXT_IN$//" | xargs -I'{}' $XARGS_FLAGS pandoc $PANDOC_ARGS   \"{}.$EXT_IN\" -o \"{}.$EXT_OUT\"
}

main() {
	fn_need_cmd "pandoc"
	fn_need_cmd "sed"
	fn_need_cmd "find"
	fn_need_cmd "xargs"
	fn_need_cmd "sort"
	fn_need_cmd "uniq"

	# PARSE ARGUMENTS
	[ $# -eq 0 ] && {
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
				XARGS_FLAGS="$XARGS_FLAGS -P${1}"
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

	[[ "$DEBUG" ]] && fn_print_params

	[[ "$EXT_IN" ]]  || fn_exit_err "EXT_IN not set" $ERR_WRONG_ARG
	[[ "$EXT_OUT" ]] || fn_exit_err "EXT_OUT not set" $ERR_WRONG_ARG

	m_say "generating..."
	fn_gen_files
	m_say "done!"
}

main "$@"
