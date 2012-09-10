#!/bin/sh
#
# Script to configure an interface
# Interface name is passed as $1
# Source ifcfg-<interface> if present for config variables
#

SRCSV=/etc/sv
DSTSV=/service

if test -z "$1"; then
    echo "No interface specified to ifcfg"
    exit 1
fi

interface=$1 
echo "Configuring interface $interface"

source /etc/find-env

if test -e "/etc/ifcfg-$interface"; then
    source /etc/ifcfg-$interface
else
    echo "Warning: No /etc/ifcfg-$interface found; DHCP only"
    dhcp_config="require"
fi

echo "Bringing up interface $interface"
/sbin/ifconfig $interface up
# wait for interface to come up before configuring further
sleep 3

if test "$dhcp_config" != "require"; then
    if test -n "$netmask"; then
        nm_arg="netmask $netmask"
    fi
    if test -n "$ip_addr"; then
        echo "Setting switch IP address to $ip_addr"
        /sbin/ifconfig $interface $ip_addr $nm_arg
    fi

    # Install a default gateway (add netmask if needed)
    if test -n "$gateway"; then
        echo "Adding gateway $gateway"
        route add default gw $gateway
    fi
else
    echo "Only DHCP used for $interface"
fi

# In any case, run dhcp client if not disabled
if test "$dhcp_config" != "disable"; then
    # Since udhcpc can be started up for more than one interface,
    # copy the entire service directory to /etc/sv/udhcpc-<interface> first
    # to avoid having multiple "supervise" directories.
    cp -a $SRCSV/udhcpc/ $SRCSV/udhcpc-$interface
    ln -sf $SRCSV/udhcpc-$interface $DSTSV
else
    echo "DHCP client is disabled for $interface"
fi
