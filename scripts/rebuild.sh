#!/bin/bash

# display usage
function usage() {
	echo "`basename $0`: Rebuild OS Template"
	echo "Usage:

`basename $0` -n <name of template VM>"
	exit 255
}

# get command-line args
while getopts "n:" OPTION; do
	case $OPTION in
		n) template="${OPTARG}";;
		*) usage;;
	esac
done

# ensure argument was passed
if [ -z "${template}" ]; then
  usage
fi

