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

WG_EXIT_ON_ERROR_MAX=${WG_EXIT_ON_ERROR_MAX:-15}

WG_HEALTHCHECK_ENDPOINT=${WG_HEALTHCHECK_ENDPOINT:-''}

LOG_LEVEL=${LOG_LEVEL:-debug}

WG_DEBUG=$([ "$LOG_LEVEL" == 'debug'  ] && echo 1 || echo 0)
WG_DEBUG_VERBOSE=$([ "$LOG_LEVEL" == 'verbose'  ] && echo 1 || echo 0)

wg_up () {
    debug wg_up "${WG_CONF}"

    chmod 600 $WG_CONF

    wg-quick up $WG_CONF

    # Try restoring from a backup in case of error.
    if [ $? -ne 0 ]; then
        wg_restore

        if [ $? -eq 0 ]; then
            wg_up

            return $?
        else
            debug wg_up "unable to restore from backup"
            abort
        fi
    fi

    return 0
}

wg_down () {
    if [[ ! $(wg show | grep $WG_INAME) ]]; then
        return 1
    fi

    debug wg_down "${WG_CONF}"

    wg-quick down $WG_CONF

    return $?
}

wg_backup() {
    if [ -f $WG_CONF ]; then
        debug wg_backup "${WG_CONF}"

        cp $WG_CONF $WG_CONF_BK

        return $?
    fi

    return 1
}

wg_restore () {
    if [ -f "$WG_CONF_BK" ]; then
        debug wg_restore "${WG_CONF}"

        mv $WG_CONF_BK $WG_CONF

        return $?
    fi

    return 1
}

finish () {
    debug finish "$@"

    wg_down

    exit 0
}

abort () {
    debug abort "$@"

    wg_down

    [[ -z "$(jobs -p)" ]] || kill $(jobs -p)

    pkill -P $$

    exit 1
}

rnd() {
    # Generate a random number for the sleep duration,
    # to avoid having multiple endpoints pinging the remote
    # at the exact same time in case of automated deployments.

    echo $(($WG_SLEEP_MIN + $RANDOM % ($WG_SLEEP_MAX - $WG_SLEEP_MIN)))
}

debug() {
    local prefix="$1"
    shift
    local msg="$@"

    if [ ${WG_DEBUG} -eq 1 ] || [ ${WG_DEBUG_VERBOSE} -eq 1 ]; then
        echo "[${prefix}] ${msg}"
    fi
}

healthcheck () {
    target=${WG_HEALTHCHECK_ENDPOINT}
    if [ ! "$target" ]; then
        debug healthcheck "Disabled ('WG_HEALTHCHECK_ENDPOINT' not specified)"
        return 0
    fi

    debug healthcheck "Start on ${target}"

    max_error_count=${WG_EXIT_ON_ERROR_MAX}
    error_count=0

    while [ ${error_count} -lt ${max_error_count} ]; do
        sleep_duration_s=$(rnd)

        if [ ${WG_DEBUG_VERBOSE} -eq 1 ]; then
            debug healthcheck "Next check in ${sleep_duration_s} seconds"
        fi

        sleep ${sleep_duration_s}

        # Check if wireguard interface is up.
        wg show ${WG_INAME} >/dev/null 2>&1
        show_exit_code=$?
        if [ ${show_exit_code} -ne 0 ]; then
            debug healthcheck "Wireguard interface is down, skipping healthcheck"
            continue
        fi

        # Try pinging our destination.
        # 1 ping, with max waiting time of 2 seconds.
        ping -c 1 -w 2 -W 2 -q ${target} >/dev/null 2>&1
        ping_exit_code=$?

        if [ ${ping_exit_code} -ne 0 ]; then
            # Increment error counter on error
            error_count=$((error_count+1))
            debug healthcheck "Failed (Attempt ${error_count}/${max_error_count})"
            continue
        fi

        # Reset error counter if successful
        error_count=0

        if [ ${WG_DEBUG_VERBOSE} -eq 1 ]; then
            debug healthcheck "Success"
        fi
    done

    # healthcheck aborted
    abort healthcheck
}

auto_conf () {
    target=${WG_CONF_URL}

    if [ ! "$target" ]; then
        debug auto-conf "Disabled ('WG_CONF_URL' not specified)"
        return 0
    fi

    max_error_count=${WG_EXIT_ON_ERROR_MAX}
    error_count=0

    debug auto-conf "Start on ${target}"

    while [ $error_count -lt $max_error_count  ]; do
        # Sleep now and set next sleep duration
        sleep_duration_s=$(rnd)

        if [ ${WG_DEBUG_VERBOSE} -eq 1 ]; then
            debug auto-conf "Next check in ${sleep_duration_s} seconds"
        fi

        sleep $sleep_duration_s

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
                $target
        )
        response_exit_code=$?

        # Handle errors
        if [ $response_exit_code -ne 0 ] || [[ $response_http_code != "200" ]]; then
            # Keep track of number of errors
            error_count=$((error_count+1))

            debug auto-conf "Wireguard unable to retrieve config from $target (Attempt ${error_count}/${max_error_count})"
            debug auto-conf "Server responded with HTTP code: $response_http_code"

            # Clean up temporary file
            if [ -f $WG_CONF_TMP ]; then
                rm $WG_CONF_TMP
            fi

            continue
        fi

        # Reset error counter after successful request
        error_count=0

        # Generate and compare md5 hashes for the current and new config files.
        current_md5=""
        if [ -f $WG_CONF ]; then
            current_md5=$(md5sum $WG_CONF | awk '{print $1}')
        fi
        new_md5=$(md5sum $WG_CONF_TMP | awk '{print $1}')

        # Handle config file change.
        if [[ $current_md5 != $new_md5 ]]; then
            debug auto-conf "New config received (${new_md5})"

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
            # before restarting wireguard.
            mv $WG_CONF_TMP $WG_CONF

            # Start wireguard.
            wg_up
        else
            # Clean up temporary file
            rm $WG_CONF_TMP
        fi
    done

    # auto-conf aborted
    abort auto-conf
}

echo "-------------------------------"
echo "[wg] WG_INAME: ${WG_INAME}"
echo "[wg] WG_CONF_DIR: ${WG_CONF_DIR}"
echo "[wg] WG_CONF_URL: ${WG_CONF_URL}"
echo "[wg] WG_CONF_AUTH_TOKEN: ${WG_CONF_AUTH_TOKEN}"
echo "[wg] WG_SLEEP_MIN: ${WG_SLEEP_MIN}"
echo "[wg] WG_SLEEP_MAX: ${WG_SLEEP_MAX}"
echo "[wg] WG_EXIT_ON_ERROR_MAX: ${WG_EXIT_ON_ERROR_MAX}"
echo "[wg] WG_HEALTHCHECK_ENDPOINT: ${WG_HEALTHCHECK_ENDPOINT}"
echo "[wg] WG_DEBUG: ${WG_DEBUG}"
echo "[wg] WG_DEBUG_VERBOSE: ${WG_DEBUG_VERBOSE}"
echo "-------------------------------"

# Try to exit cleanly
trap finish SIGTERM SIGINT SIGQUIT SIGHUP

# Ensure config directory exists.
# This may occur when no wg config was given to start with
# and will be retrieving it from `WG_CONF_URL` on load.
mkdir -p $WG_CONF_DIR

# Start wireguard or fail if no config url specified.
if [ -f $WG_CONF ]; then
    wg_up
elif [[ ! "$WG_CONF_URL" ]]; then
    echo "wireguard config not found"
    exit 1;
fi

# Check for conf updates in a background process.
auto_conf &

# Healthchecks in a background process.
healthcheck &

. /usr/bin/nginx-auto &

# Keep running if no auto-conf and no healthchecks.
if [ ! "${WG_CONF_URL}" ] && [ ! "${WG_HEALTHCHECK_ENDPOINT}" ]; then
    sleep infinity &
fi

# Wait for all background processes to complete.
# This keeps the main process running.
wait

# If we're here something went wrong, abort.
abort
