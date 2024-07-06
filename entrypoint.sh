#!/bin/bash

finish () {
    wg-quick down wg0
    exit 0
}
trap finish SIGTERM SIGINT SIGQUIT

wg-quick up /etc/wireguard/wg0.conf

# Infinite sleep
sleep infinity &

# Health check
/usr/bin/healthcheck &
wait $!
