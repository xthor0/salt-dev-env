#!/bin/bash

# variables
source="http://cdimage.ubuntu.com/releases/18.04.2/release/ubuntu-18.04.2-server-amd64.iso"
shatxt="http://cdimage.ubuntu.com/releases/18.04.2/release/SHA256SUMS"
build="$HOME/tmp/ubuntu-iso"
shaname=$(basename ${shatxt})
isoname=$(basename ${source})

# we need command-line options
while getopts "p:f:c:" opt; do
	case $opt in
		p)
			preseed=$OPTARG
			;;
		f)
			outfile=$OPTARG
			;;
		c)
			custom=$OPTARG
			;;
	esac
done

# validate arguments...
if [ -z "${preseed}" ]; then
	echo "You must specify the location of a Ubuntu preseed file with the -p option!"
	exit 255
fi

if [ -z "$outfile" ]; then
	echo "You must specify the base output file name with -f"
	echo "example: $(basename $0) -f vbox -- output file: ubuntu-vbox-$(date +%Y%m%d).iso"
	exit 255
fi

# custom directory containing ssh key and init files
if [ -z "$custom" ]; then
    echo "You must specify the full path to the custom dir!"
    exit 255
fi

# make sure the preseed file exists
if [ -f "${preseed}" ]; then
    echo "Using preseed file: ${preseed}"
else
    echo "Error: file not found: ${preseed}"
    exit 255
fi

# name of output file
output="ubuntu-${outfile}-$(date +%Y%m%d).iso"

# create the build directory
if [ ! -d "${build}" ]; then
    mkdir -p "${build}"
fi

pushd "${build}"

# download the SHA512SUMS file
wget -q ${shatxt}
if [ $? -eq 0 ]; then
    echo "$(grep ${isoname} SHA256SUMS | awk '{ print $1 }')  ${isoname}" > sha.txt
else
    echo "Error: Unable to download ${shatxt}. Exiting."
    exit 255
fi

# download the netinst ISO
if [ -f ${isoname} ]; then
    echo "${isoname} has already been downloaded."
else
    echo "Downloading ${source}..."
    wget --no-clobber --show-progress -q ${source}
fi

# check hash
if [ $? -eq 0 ]; then
    sha256sum -c sha.txt
    if [ $? -ne 0 ]; then
        echo "Failed to verify SHA512SUM of ${isoname} -- exiting."
        exit 255
    fi
else
    echo "Unable to download ISO."
    exit 255
fi

# extract the ISO
7z -ox x ${isoname}
if [ $? -ne 0 ]; then
    echo "Failed to extract ${isoname} -- exiting."
    exit 255
fi

# copy in the custom dir
mkdir x/custom && cp -ar ${custom}/* x/custom
if [ $? -ne 0 ]; then
    echo "Failed to copy ${custom} to ISO root -- exiting."
    exit 255
fi

# replace isolinux.cfg
cat << EOF > x/isolinux/isolinux.cfg 
default linux
timeout 200

label linux
	menu label ^Install
    kernel /install/vmlinuz
    append auto file=/cdrom/preseed.cfg vga=788 initrd=/install/initrd.gz debconf/priority=critical locale=en_US console-setup/ask_detect=false console-setup/layoutcode=us netcfg/do_not_use_netplan=true
EOF
if [ $? -ne 0 ]; then
    echo "Failed to write isolinux.cfg -- exiting."
    exit 255
fi

# inject preseed.cfg
cp ${preseed} x/preseed.cfg
if [ $? -ne 0 ]; then
    echo "Error copying ${preseed} -- exiting."
    exit 255
fi

# generate ISO
echo "Generating ISO: ${build}/${output}"
genisoimage -quiet -r -J -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ${build}/${output} x
if [ $? -eq 0 ]; then
    # cleanup
    rm -rf x ${shaname} sha.txt
else
    echo "Error generating ISO."
fi

popd
exit 0