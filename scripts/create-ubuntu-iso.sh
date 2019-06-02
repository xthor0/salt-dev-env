#!/bin/bash

# variables
build="$HOME/tmp/ubuntu-iso"

# we need command-line options
while getopts "p:f:c:v:" opt; do
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
        v)
            version=${OPTARG};;
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

# make sure an Ubuntu version was specified
if [ -z "${version}" ]; then
    echo "You must specify the version of Ubuntu to use."
    exit 255
fi

# make sure a valid release number was specified
ubvers=$(curl -s http://mirrors.xmission.com/ubuntu-cd/ | sed -e 's/<[^>]*>//g' | grep '^[0-9]' | cut -d \/ -f 1 | tr \\n ' ')
if [ $? -eq 0 ]; then
    echo ${ubvers} | grep -qw ${version}
    if [ $? -ne 0 ]; then
        echo "Invalid Ubuntu version specified. Valid Ubuntu versions:"
        echo ${ubvers}
        exit 255
    fi
else
    echo "Error downloading list of Ubuntu releases from http://mirrors.xmission.com/ubuntu-cd/ - exiting."
    exit 255
fi

# make sure the preseed file exists
if [ -f "${preseed}" ]; then
    echo "Using preseed file: ${preseed}"
else
    echo "Error: file not found: ${preseed}"
    exit 255
fi

# verify all binaries are present
for binary in wget curl genisoimage sha256sum; do
    which ${binary} >& /dev/null
    if [ $? -eq 1 ]; then
        echo "Unable to locate ${binary} - please install and run this script again."
        exit 255
    fi
done

# name of output file
output="ubuntu-${version}-${outfile}-$(date +%Y%m%d).iso"

# set variables for where we'll download the ISO and SHASUM file
source="http://mirrors.xmission.com/ubuntu-cd/${version}/ubuntu-${version}-server-amd64.iso"
shatxt="http://mirrors.xmission.com/ubuntu-cd/${version}/SHA256SUMS"
shaname=$(basename ${shatxt})
isoname=$(basename ${source})

# create the build directory
if [ ! -d "${build}" ]; then
    mkdir -p "${build}"
fi

pushd "${build}"

# download the SHA512SUMS file
hash=$(curl -s ${shatxt} | grep ${isoname} | awk '{ print $1 }')
if [ $? -eq 0 ]; then
    echo "${hash}  ${isoname}" > sha.txt
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

# get rid of the extract directory if it exists from a previous run
if [ -d x ]; then
    rm -rf x 
fi

# extract the ISO
# unfortunately, 7z truncates the damn files... so...
#7z -ox x ${isoname}
#if [ $? -ne 0 ]; then
#    echo "Failed to extract ${isoname} -- exiting."
#    exit 255
#fi
echo "You will be prompted for your sudo password to mount the ISO."
mkdir iso_src && sudo mount -o loop ${isoname} iso_src
if [ $? -ne 0 ]; then
    echo "Error: Unable to mount ISO."
fi

# create a target directory, and copy the ISO source to it
echo "Copying iso contents to new directory..."
cp -ar iso_src iso_tgt
if [ $? -ne 0 ]; then
    echo "Error copying mounted ISO files to new directory."
    exit 255
fi

# unmount iso
echo "You will be prompted for your sudo password to unmount the ISO."
sudo umount iso_src
if [ $? -ne 0 ]; then
    echo "error unmounting ISO - you'll see other errors below."
fi

# set permissions, or we can't modify anything (stupid iso)
chmod -R u+w iso_tgt
if [ $? -ne 0 ]; then
    echo "Error: unable to set permissions on iso_tgt -- exiting."
    exit 255
fi

# copy in the custom dir
mkdir iso_tgt/custom && cp -ar ${custom}/* iso_tgt/custom
if [ $? -ne 0 ]; then
    echo "Failed to copy ${custom} to ISO root -- exiting."
    exit 255
fi

# replace isolinux.cfg
cat << EOF > iso_tgt/isolinux/isolinux.cfg 
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
cp ${preseed} iso_tgt/preseed.cfg
if [ $? -ne 0 ]; then
    echo "Error copying ${preseed} -- exiting."
    exit 255
fi

# generate ISO
echo "Generating ISO: ${build}/${output}"
#genisoimage -quiet -D -l -r -J -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ${build}/${output} x
mkisofs -D -r -V "UBUNTU_${version}" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ${build}/${output} iso_tgt
if [ $? -eq 0 ]; then
    # cleanup
    rm -rf iso_src iso_tgt ${shaname} sha.txt

    echo "ISO written: ${build}/${output}"
else
    echo "Error generating ISO."
fi

popd
exit 0