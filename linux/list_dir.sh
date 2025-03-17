#!/bin/bash

# Checks permissions of important directories in the Linux filesystem

ImportantDirs="/bin /boot /dev /etc /home /lib /lib64 /media /mnt /opt /proc /root /run /sbin /srv /sys /tmp /usr /var"

for dir in $ImportantDirs
do
    echo "permissions for $dir:"
    ls -ld $dir
    echo
done


# The script lists the contents of important directories in the Linux filesystem.