#!/bin/bash

# display usage
function usage() {
	echo "`basename $0`: Deploy a new VirtualBox VM as a Salt minion."
	echo "Usage:

`basename $0` -n <name of new vm> -s <name of template> [ -r <RAM in GB> ] [ -c <vCPUs> ] [ -d <Disk space in GB> ]"
	exit 255
}

# get command-line args
while getopts "n:s:r:c:d:" OPTION; do
	case $OPTION in
		n) servername="${OPTARG}";;
    s) template="${OPTARG}";;
    r) ram="${OPTARG}";;
    c) cpu="${OPTARG}";;
    d) disk="${OPTARG}";;
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
    # resize primary hard drive
    if [ -n "${disk}" ]; then
      echo "Expanding VM hard drive to ${disk} GB..."
      # convert GB to MB
      diskMB=$((${disk} * 1024))
      storage_controller=$(vboxmanage showvminfo ${servername} | grep '^Storage Controller Name (0)' | cut -d \: -f 2- | sed -e 's/^[[:space:]]*//')
      if [ $? -eq 0 ]; then
        storage_uuid=$(vboxmanage showvminfo ${servername} | grep "^${storage_controller}" | grep UUID | awk '{ print $8 }' | sed 's/)$//g')
        if [ $? -eq 0 ]; then
          vboxmanage modifymedium disk ${storage_uuid} --resize ${diskMB}
          if [ $? -eq 0 ]; then
            echo "VM hard drive expanded to ${disk} GB."
          else
            echo "Error expanding VM hard disk - exiting."
            exit 255
          fi
        else
          echo "Unable to determine UUID of VM hard drive -- exiting."
          exit 255
        fi
      else
        echo "Unable to determine name of the storage controller - exiting."
        exit 255
      fi
    fi

    # adjust RAM
    if [ -n "${ram}" ]; then
      ramMB=$((${ram} * 1024))
      vboxmanage modifyvm ${servername} --memory ${ramMB}
      if [ $? -eq 0 ]; then
        echo "Memory adjusted to ${ram} GB"
      else
        echo "Error adjusting VM memory - exiting."
        exit 255
      fi
    fi

    # adjust vCPU
    if [ -n "${cpu}" ]; then
      vboxmanage modifyvm ${servername} --cpus ${cpu}
      if [ $? -eq 0 ]; then
        echo "vCPUs adjusted to ${cpu}"
      else
        echo "Error adjusting vCPUs - exiting."
        exit 255
      fi
    fi

    vboxmanage startvm ${servername} --type headless
  else
    echo "error setting guestproperty - exiting."
  fi
else
  echo "error cloning VM - exiting."
fi

exit 0

