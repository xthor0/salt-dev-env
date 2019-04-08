#!/bin/bash

# display usage
function usage() {
	echo "`basename $0`: Deploy a new VirtualBox VM as a Salt minion."
	echo "Usage:

`basename $0` -n <name of new vm> -s <name of template>"
	exit 255
}

# get command-line args
while getopts "n:s:" OPTION; do
	case $OPTION in
		n) servername="${OPTARG}";;
    s) template="${OPTARG}";;
		*) usage;;
	esac
done

# ensure argument was passed
if [ -z "${servername}" -o -z "${template}" ]; then
  usage
fi

# deploy
vboxmanage clonevm ${template} --name ${servername} --register
if [ $? -eq 0 ]; then
  vboxmanage guestproperty set ${servername} GuestName ${servername}
  if [ $? -eq 0 ]; then
    vboxmanage startvm ${servername} --type headless
  else
    echo "error setting guestproperty - exiting."
  fi
else
  echo "error cloning VM - exiting."
fi

exit 0

