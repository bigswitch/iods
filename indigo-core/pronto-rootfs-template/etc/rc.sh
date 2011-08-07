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

# Client specific directory (for logs, etc) is $client_root
# which is normally /client/$DEV_ADDR

echo "Running rc.sh for platform:  Pronto 3290"

echo "Bringing up local devices"
/sbin/ifconfig lo 127.0.0.1

# mount /proc so "reboot" works
/bin/mount -t proc proc /proc

# These are old; not sure they're all right
mount -t devpts devpts /dev/pts

# TODO: check if had been mounted, don't use remount option if not mounted
mount -o remount,rw /

source /etc/platform.sh

echo "Inserting core drivers for LB9A"
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
    echo "Attempting to extract SFS"
    /sbin/sfs_extract /local
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