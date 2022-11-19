#!/bin/bash

WG_INAME=${WG_INAME:-wg0}
WG_CONF_DIR=${WG_CONF_DIR:-/etc/wireguard/}

WG_CONF="${WG_CONF_DIR}${WG_INAME}.conf"
WG_CONF_TMP="${WG_CONF}.tmp"
WG_CONF_BK="${WG_CONF}.bk"

WG_CONF_URL="${WG_CONF_URL:-}"
WG_CONF_AUTH_TOKEN="${WG_CONF_AUTH_TOKEN:-}"

finish () {
    wg-quick down wg0
    exit 0
}

trap finish SIGTERM SIGINT SIGQUIT SIGHUP

wg_up () {
    echo "wireguard starting.."

    wg-quick up $WG_CONF

    if [ $? -eq 0 ]; then
        wg_backup
    else
        wg_restore

        if [ $? -eq 0 ]; then
            wg_up
        else
            echo "wireguard: unable to start"
            exit 1;
        fi
    fi
}

wg_sync () {
    echo "wireguard syncing.."

    wg syncconf $WG_INAME <(wg-quick strip $WG_INAME)

    if [ $? -eq 0 ]; then
        wg_backup
    else
        wg_restore

        if [ $? -eq 0 ]; then
            wg_sync
        else
            echo "wireguard: unable to sync"
            exit 1;
        fi
    fi
}

wg_backup() {
    if [ -f $WG_CONF ]; then
        echo "wireguard creating backup"

        cp $WG_CONF $WG_CONF_BK
        return $?
    fi

    return 1
}

wg_restore () {
    if [ -f "$WG_CONF_BK" ]; then
        echo "wireguard restoring from backup"

        mv $WG_CONF_BK $WG_CONF
        return $?
    fi

    return 1
}

if [ -f $WG_CONF ]; then

    wg_up

elif [[ ! "$WG_CONF_URL" ]]; then
    echo "wireguard config not found"
    exit 1;
fi

if [[ "$WG_CONF_URL" ]]; then
    echo "Wireguard auto-config mode"

    while sleep 15; do

        curl_auth_header=''
        if [[ "$WG_CONF_AUTH_TOKEN" ]]; then
            curl_auth_header="Authorization: Bearer $WG_CONF_AUTH_TOKEN"
        fi

        response=$(
            curl \
                --connect-timeout 2 \
                --max-time 5 \
                --output $WG_CONF_TMP \
                --silent  \
                 -H "$curl_auth_header" \
                $WG_CONF_URL
        )

        if [ $? -ne 0 ]; then
            echo ""
            echo "Unable to retrieve config"
            echo $response
            echo "Retriving in 5 seconds.."
            sleep 5

            continue
        fi

        current_md5=$(md5sum $WG_CONF | awk '{print $1}')
        new_md5=$(md5sum "$WG_CONF_TMP" | awk '{print $1}')

        if [[ $current_md5 != $new_md5 ]]; then
            echo ""
            echo "Wireguard new config received"

            mv $WG_CONF_TMP $WG_CONF

            wg_exists=$(wg show $WG_INAME)
            if [ $? -eq 0 ]; then
                wg_sync
            else
                wg_up
            fi

            echo "Waiting for config update.."
            echo ""
        fi
    done
else
    # Inifinite sleep
    sleep infinity &
    wait $!
fi
