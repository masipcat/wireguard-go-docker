#!/bin/bash

finish () {
    wg-quick down wg0
    exit 0
}
trap finish SIGTERM SIGINT SIGQUIT

wg-quick up /etc/wireguard/wg0.conf

# Inifinite sleep
while true; do
    sleep 86400
    wait $!
done
