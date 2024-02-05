#!/bin/bash

set -e

echo "nginx-auto"

nginx_up() {
    if [ -f "/run/nginx/nginx.pid" ]; then
        nginx -s reload
    else
        nginx
    fi

    cp -r /etc/nginx /data

    echo "tail logs"

    tail -f -n 1 /var/log/nginx/*.log
}

main() {
    echo "main"

    gomplate \
        --file=/etc/ng/templates/nginx-ng.sh \
        --out=/data/nginx-ng.sh \
        --datasource nginx=file:///data/nginx.yaml

    #
    # Public templates (/etc/ng/public)
    # These include custom 40x and 50x error templates.
    #
    gomplate \
        --input-dir=/etc/ng/templates/public \
        --output-dir=/etc/ng/public \
        --template=/etc/ng/templates \
        --datasource nginx=file:///data/nginx.yaml

    #
    # Main nginx.conf (/etc/nginx/nginx.conf)
    #
    gomplate \
        --file=/etc/ng/templates/nginx.conf \
        --out=/etc/nginx/nginx.conf \
        --template=/etc/ng/templates \
        --datasource nginx=file:///data/nginx.yaml

    nginx_up

}


if [ "$0" != "" ]; then
    main &
fi
