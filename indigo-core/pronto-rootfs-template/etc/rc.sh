#!/bin/sh
#
# Initialization script for OpenFlow release of Quanta switch
#
# See README-config or the OpenFlow wiki for more information
#
# The key environment variable that should be defined is DEV_ADDR
# that identifies the client.

# Order of priority for location of init files
# $client_cfg/ (/config/$DEV_ADDR)
# /config/default/
# /etc/
#
# If SFS includes an nfs_path file, an NFS mount will be added, which is useful
# for:
# - defining a custom sysenv file outside of the main Indigo image
# - storing logs to NFS when using a tftpboot'ed image
#    (if log_dir is set in sysenv on the NFS mount)
# The contents of nfs_path should be an IP and mount dir separated by a colon.
#
# Example setup, from a switch console:
#   mkdir -p /sfs
#   echo '192.168.1.11:/var/exports/shared' > /sfs/nfs_path
#   cd sfs
#   sfsctl create *

# Client specific directory (for logs, etc) is $client_root
# which is normally /client/$DEV_ADDR

echo "Running rc.sh"

echo "Bringing up local devices"
/sbin/ifconfig lo 127.0.0.1

# mount /proc so "reboot" works
/bin/mount -t proc proc /proc

# These are old; not sure they're all right
mount -t devpts devpts /dev/pts

# TODO: check if had been mounted, don't use remount option if not mounted
mount -o remount,rw /

source /etc/platform.sh
echo "Platform: $platform. Vendor: $vendor"

if test -n "$t2ref"; then
    # Assumes T2 ref is using NFS for file system for now
    mkdir -p /local
    touch /local/sysenv
else
    echo "Inserting core drivers"
    insmod /lib/modules/cpuDrv.ko
    insmod /lib/modules/flashDrv.ko
    insmod /lib/modules/i2cDrv.ko
    insmod /lib/modules/pciDrv.ko
    # 3240 is special cased (in else below)
    if test -z "$p3240"; then
        insmod /lib/modules/wdtDrv.ko
        if test ! -d /cf_card; then
            mkdir -p /cf_card
        fi
        mount /dev/hda1 /cf_card
    else
        echo "Attempting to extract SFS on 3240"
        /sbin/sfs_extract /local

	# If nfs_path is a file in SFS, mount NFS dir.
	sfs_dir=/local/sfs
        if test -e "$sfs_dir/nfs_path"; then
            export nfs_path=`cat $sfs_dir/nfs_path`
            export nfs_dir=/mnt/nfs
            echo "Mounting $nfs_path as $nfs_dir"
            mkdir -p $nfs_dir
            mount -t nfs -o nolock,rw $nfs_path $nfs_dir
        else
            echo "Not mounting NFS dir"
        fi
    fi
fi

source /etc/find-env

if test -f $config_dir/indigo-preinit.sh; then
    echo "Sourcing $config_dir/indigo-preinit.sh"
    source $client_root/indigo-preinit.sh
fi

if test -e $sys_init_file; then
    echo "Running $sys_init_file"
    source $sys_init_file
else
    echo "No system init file found; manual config required"
fi
