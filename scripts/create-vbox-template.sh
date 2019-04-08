#!/bin/bash

# display usage
function usage() {
    echo "Error: Incorrect options specified!"
    echo
	echo "$(basename $0): Build a template for use with VirtualBox."
    echo
	echo "Usage:

$(basename $0) -n <name of virtualbox vm> -c <path to ISO>"

	exit 255
}


# we need command-line options
while getopts "n:c:" opt; do
	case $opt in
		n)
			name=$OPTARG
			;;
		c)
			iso=$OPTARG
			;;
        *)
            usage;;
	esac
done

# validate arguments...
if [ -z "${name}" -o -z "${iso}" ]; then
    usage
fi

if [ ! -f "${iso}" ]; then
    echo "Unable to access ISO: ${iso}"
    exit 255
fi

vboxmanage list vms | grep -wq ${name}
if [ $? -eq 1 ]; then
    VBoxManage createvm --name ${name} --ostype Ubuntu_64 --register
    if [ $? -eq 0 ]; then
        VBoxManage modifyvm ${name} --memory 1024
        if [ $? -eq 0 ]; then
            vboxmanage modifyvm ${name} --nic1 hostonly --hostonlyadapter1 vboxnet0
            if [ $? -eq 0 ]; then
                VBoxManage createhd --filename ~/VirtualBox\ VMs/${name}/${name}.vdi --size 8000 --format VDI
                if [ $? -eq 0 ]; then
                    VBoxManage storagectl ${name} --name "SATA Controller" --add sata --controller IntelAhci --portcount 2
                    if [ $? -eq 0 ]; then
                        VBoxManage storageattach ${name} --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium ~/VirtualBox\ VMs/${name}/${name}.vdi
                        if [ $? -eq 0 ]; then
                            VBoxManage storageattach ${name} --storagectl "SATA Controller" --port 1 --device 0 --type dvddrive --medium "${iso}"
vboxmanage startvm ${name}
                            if [ $? -eq 0 ]; then
                                retval=0
                            fi
                        else
                            retval=1
                        fi
                    else
                        retval=1
                    fi
                else
                    retval=1
                fi
            else
                retval=1
            fi
        else
            retval=1
        fi
    else
        retval=1
    fi
else
    echo "VM already exists."
    retval=1
fi

if [ ${retval} -eq 1 ]; then
    echo "Error creating VM ${name} -- see output above."
else
    echo "VM ${name} created successfully."
fi
