#!/bin/bash

wg-quick up /etc/wireguard/wg0.conf

# Handle shutdown behavior
finish () {
    wg-quick down wg0
    exit 0
}

trap finish SIGTERM SIGINT SIGQUIT

while true; do
    sleep 86400
    wait $!
done
