#!/bin/sh
if [ -n "$(pidof unbound)" ];then
    echo -e server=127.0.0.1#53535 > /etc/dnsmasq.custom
    echo -e no-resolv >> /etc/dnsmasq.custom
    echo -e cache-size=0 >> /etc/dnsmasq.custom
    echo -e no-poll >> /etc/dnsmasq.custom
    service dnsmasq restart
    echo "nameserver 127.0.0.1" > /etc/resolv.dnsmasq
fi
