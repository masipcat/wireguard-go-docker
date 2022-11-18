#!/bin/bash

finish () {
    wg-quick down wg0
    exit 0
}
trap finish SIGTERM SIGINT SIGQUIT SIGHUP

wg_up () {
    echo "wireguard starting.."

    wg-quick up /etc/wireguard/wg0.conf

    if [ $? -ne 0 ]; then
        wg_restore

        if [ $? -eq 0 ]; then
            wg_up
        else
            echo "wireguard: unable to start"
            exit 1;
        fi
    else
        wg_backup
    fi
}

wg_sync () {
    echo "wireguard syncing.."

    wg syncconf wg0 <(wg-quick strip wg0)

    if [ $? -ne 0 ]; then
        wg_restore

        if [ $? -eq 0 ]; then
            wg_sync
        else
            echo "wireguard: unable to sync"
            exit 1;
        fi
    else
        wg_backup
    fi
}

wg_backup() {
    if [ -f /etc/wireguard/wg0.conf ]; then
        cp /etc/wireguard/wg0.conf $WG_CONF_BK
        echo "wireguard backup created"
        return $?
    fi

    return 1
}

wg_restore () {
    if [ -f "$WG_CONF_BK" ]; then
        mv $WG_CONF_BK /etc/wireguard/wg0.conf
        echo "wireguard backup restored"
        return $?
    fi

    return 1
}

get_config () {
    curl --silent --output "$WG_CONF_TMP" "$WG_CONF_URL"
    checksum=$(md5sum "$WG_CONF_TMP" | awk '{print $1}')
    echo "$checksum"
}

WG_CONF_TMP='wg0.conf.tmp'
WG_CONF_BK='wg0.conf.bk'

if [ -f /etc/wireguard/wg0.conf ]; then
    wg_up
elif [[ ! "$WG_CONF_URL" ]]; then
    echo "No config found"
    exit 1;
fi

if [[ "$WG_CONF_URL" ]]; then
    echo "Auto-config mode"

    while sleep 2; do
        current_md5=$(md5sum /etc/wireguard/wg0.conf | awk '{print $1}')
        new_md5=$(get_config | tail -n1)

        if [[ $current_md5 != $new_md5 ]]; then
            echo "Wireguard new config received"

            mv $WG_CONF_TMP /etc/wireguard/wg0.conf

            wg_exists=$(wg show wg0)
            if [ $? -eq 0 ]; then
                wg_sync
            else
                wg_up
            fi

            echo "Waiting for config updates..."
        fi
    done
else
    # Inifinite sleep
    sleep infinity &
    wait $!
fi
