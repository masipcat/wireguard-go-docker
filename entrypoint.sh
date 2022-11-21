#!/bin/bash

WG_INAME=${WG_INAME:-wg0}
WG_CONF_DIR=${WG_CONF_DIR:-/etc/wireguard/}

WG_CONF="${WG_CONF_DIR}${WG_INAME}.conf"
WG_CONF_TMP="${WG_CONF}.tmp"
WG_CONF_BK="${WG_CONF}.bk"

WG_CONF_URL="${WG_CONF_URL:-}"
WG_CONF_AUTH_TOKEN="${WG_CONF_AUTH_TOKEN:-}"

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

wg_down () {
    echo ""
    echo "wireguard stopping.."

    wg-quick down $WG_CONF
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

finish () {
    wg_down

    exit 0
}

# Try to exit cleanly
trap finish SIGTERM SIGINT SIGQUIT SIGHUP

# Ensure config directory exists.
# This may occur when no wg config was given to start with
# and will be retrieving it from `WG_CONF_URL` on load.
#
# TODO:
#       - [?] Folder / File Permissions
#             Warning: `/etc/wireguard/wg0.conf' is world accessible
mkdir -p $WG_CONF_DIR

# Start wireguard or fail if no config url specified.
if [ -f $WG_CONF ]; then
    wg_up
elif [[ ! "$WG_CONF_URL" ]]; then
    echo "wireguard config not found"
    exit 1;
fi

if [[ "$WG_CONF_URL" ]]; then
    echo "Wireguard listening for config changes"

    while true; do
        # generate a random number for the sleep duration
        # to avoid having multiple endpoints pinging the remote
        # at the same time.
        sleep_duration_s=$((1 + $RANDOM % 120))

        curl_auth_header=''
        if [[ "$WG_CONF_AUTH_TOKEN" ]]; then
            curl_auth_header="Authorization: Bearer $WG_CONF_AUTH_TOKEN"
        fi

        response=$(
            curl \
                --connect-timeout 2 \
                --max-time 5 \
                --no-progress-meter \
                --output $WG_CONF_TMP \
                 -H "$curl_auth_header" \
                $WG_CONF_URL
        )

        if [ $? -ne 0 ]; then
            echo ""
            echo "Wireguard unable to retrieve config. Server responded with:"
            echo $response
            echo "Retrying in $sleep_duration_s seconds.."
            sleep $sleep_duration_s

            continue
        fi

        current_md5=""
        if [ -f $WG_CONF ]; then
            current_md5=$(md5sum $WG_CONF | awk '{print $1}')
        fi

        new_md5=$(md5sum "$WG_CONF_TMP" | awk '{print $1}')

        if [[ $current_md5 != $new_md5 ]]; then
            echo ""
            echo "Wireguard new config received"

            mv $WG_CONF_TMP $WG_CONF

            # Bring down the existing wireguard interface
            # so as to trigger existing PostDown commands.
            #
            # This is in case Pre/Post Up/Down commands have changed
            # since last time and we want to make sure clean-up tasks
            # from the previous config are applied before changing configs.
            #
            # Also, this makes sure that ip table rules are properly applied
            # in case the AllowedIPs have changed between configs -
            # apparently these are only applied when the interface is started,
            # not when it is updated.
            if [[ $(wg show | grep $WG_INAME) ]]; then
                wg_down
            fi

            wg_up

            echo "Waiting for config update.."
            echo ""
        else
            # Clean up temporary file
            rm $WG_CONF_TMP
        fi

        sleep $sleep_duration_s
    done

    echo ""
    echo "Wireguard auto-config exited"

    finish
else
    # Inifinite sleep
    sleep infinity &
    wait $!
fi
