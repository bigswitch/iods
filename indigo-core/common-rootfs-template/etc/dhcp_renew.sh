#!/bin/sh

RESOLV_CONF="/etc/resolv.conf"

echo "`date`: Running udhcpc script renew.sh"
echo "Iterface: $interface"
echo "IP: $ip"
echo "Subnet: $subnet"
echo "DNS: $dns"
echo "router: $router"

[ -n "$broadcast" ] && BROADCAST="broadcast $broadcast"
[ -n "$subnet" ] && NETMASK="netmask $subnet"

/sbin/ifconfig $interface $ip $BROADCAST $NETMASK

if [ -n "$router" ];  then 
    while /sbin/route del default gw 0.0.0.0 dev $interface; do
        echo "deleted default gw"
    done

    for i in $router; do
        /sbin/route add default gw $i dev $interface
        echo Added router $i
    done
fi

if [ -n "$dns" ]; then
    echo "Setting DNS"
    if [ -e $RESOLV_CONF ]; then
        cp -f $RESOLV_CONF $RESOLV_CONF.old
    fi
    echo "nameserver $dns" > $RESOLV_CONF
    echo "domain $domain" >> $RESOLV_CONF
fi

if [ -n "$vendorext" ]; then
    echo "Vendor extension: $vendorext"

    # get current controller_ip and controller_port
    source /etc/find-env

    ORIG_IFS=$IFS
    IFS=":"
    set -- $vendorext
    if [ -n "$1" -a -n "$2" ]; then
        # check for changes to controller_ip and _port
        # to avoid unnecessarily restarting openflow daemons
        if [ "$controller_ip" != "$1" -o "$controller_port" != $2 ]; then
            echo "Building new sysenv"
            newsysenv=/tmp/newsysenv
            origsysenv=$config_dir/sysenv
            # replace controller_ip and controller_port
            sed -e "/controller_ip=/s/$controller_ip/$1/" \
                -e "/controller_port=/s/$controller_port/$2/" \
                $origsysenv > $newsysenv
            mv -f $newsysenv $origsysenv
            /sbin/of-restart
        fi
    fi
    IFS=$ORIG_IFS
fi
