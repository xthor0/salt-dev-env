#!/bin/bash

# this is a script that will clean up a VM image to make it suitable to use as a template.
# it should be executed on shutdown only, by systemd. see template-cleanup.service file.

hostname | grep -qi template
if [ $? -eq 0 ]; then
    # script will only run on a system that has a hostname with "template" in it
    exit 0
fi

# cleanup package management
if [ -x /usr/bin/apt-get ]; then
    apt-get clean
fi

if [ -x /usr/bin/yum ]; then
    yum clean all
    yum history new
fi

# clear system logs
journalctl --rotate
journalctl --vacuum-time=1s

# zero out logs on disk
find /var/log -type f | while read file; do 
    cat /dev/null > ${file}
done

# cleanup /tmp directories
rm -rf /tmp/*
rm -rf /var/tmp/*


# cleanup shell history and other unnecessary files
rm -f /root/.bash_history /root/*ks.cfg

# we only run this once
systemctl disable template-cleanup
rm /etc/systemd/system/template-cleanup.service
rm -f ${0}
