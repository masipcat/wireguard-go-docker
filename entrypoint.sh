#!/bin/bash

WG_INAME=${WG_INAME:-wg0}
WG_CONF_DIR=${WG_CONF_DIR:-/etc/wireguard/}

WG_CONF="${WG_CONF_DIR}${WG_INAME}.conf"
WG_CONF_TMP="${WG_CONF}.tmp"
WG_CONF_BK="${WG_CONF}.bk"

WG_CONF_URL="${WG_CONF_URL:-}"
WG_CONF_AUTH_TOKEN="${WG_CONF_AUTH_TOKEN:-}"

WG_SLEEP_MIN=${WG_SLEEP_MIN:-45}
WG_SLEEP_MAX=${WG_SLEEP_MAX:-180}

WG_DEBUG=${WG_DEBUG:-0}

wg_up () {
    echo "wireguard starting.."

    wg-quick up $WG_CONF

    # Try restoring from a backup in case of error.
    if [ $? -ne 0 ]; then
        wg_restore

        if [ $? -eq 0 ]; then
            wg_up
        else
            echo "wireguard: unable to start"

            if [[ ! "$WG_CONF_URL" ]]; then
                echo "wireguard exiting with error"
                exit 1;
            fi
        fi
    fi

    return 0
}

wg_down () {
    if [[ ! $(wg show | grep $WG_INAME) ]]; then
        return 1
    fi

    echo ""
    echo "wireguard stopping.."

    wg-quick down $WG_CONF

    return $?
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
    echo "Wireguard exiting"

    wg_down

    exit 0
}


rnd() {
    # Generate a random number for the sleep duration,
    # to avoid having multiple endpoints pinging the remote
    # at the exact same time in case of automated deployments.

    echo $(($WG_SLEEP_MIN + $RANDOM % ($WG_SLEEP_MAX - $WG_SLEEP_MIN)))
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

    sleep_duration_s=$(rnd)

    echo "Wireguard waiting for config changes in ${sleep_duration_s} seconds"

    while true; do
        # Sleep now and set next sleep duration
        sleep $sleep_duration_s
        sleep_duration_s=$(rnd)

        curl_auth_header=''
        if [[ "$WG_CONF_AUTH_TOKEN" ]]; then
            curl_auth_header="Authorization: Bearer $WG_CONF_AUTH_TOKEN"
        fi

        response_http_code=$(
            curl \
                --connect-timeout 2 \
                --max-time 5 \
                --no-progress-meter \
                --output $WG_CONF_TMP \
                --write-out "%{http_code}" \
                 -H "$curl_auth_header" \
                $WG_CONF_URL
        )

        # Try again in case the request failed
        if [ $? -ne 0 ] || [[ $response_http_code != "200" ]]; then
            echo ""
            echo "Wireguard unable to retrieve config from $WG_CONF_URL."
            echo "Server responded with HTTP code: $response_http_code"

            # Clean up temporary file
            if [ -f $WG_CONF_TMP ]; then
                cat $WG_CONF_TMP
                rm $WG_CONF_TMP
            fi

            echo ""
            echo "Retrying in ${sleep_duration_s} seconds.."

            continue
        fi

        # Generate and compare md5 hashes for the current and new config files.
        current_md5=""
        if [ -f $WG_CONF ]; then
            current_md5=$(md5sum $WG_CONF | awk '{print $1}')
        fi
        new_md5=$(md5sum "$WG_CONF_TMP" | awk '{print $1}')

        if [[ $current_md5 != $new_md5 ]]; then
            echo ""
            echo "Wireguard new config received"

            # Create a backup of our existing config to revert to
            # in case of errors when loading the new config.
            wg_backup

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
            wg_down

            # Move temporary file to expected destination
            # and start wireguard.
            mv $WG_CONF_TMP $WG_CONF

            wg_up
        else
            # Clean up temporary file
            rm $WG_CONF_TMP
        fi

        if [[ $WG_DEBUG ]]; then
            echo "Wireguard auto-conf next check in ${sleep_duration_s} seconds"
        fi
    done

    echo ""
    echo "Wireguard auto-config exited"

    finish
else
    # Inifinite sleep
    sleep infinity &
    wait $!
fi
