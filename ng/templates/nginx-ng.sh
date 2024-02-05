#!/bin/bash

# find all servers with auto_ssl
# issue self-signed certificates (/data/ng/certs)
# ? wildcard
#
# add 443 ssl to nginx template
#
# nginx change, reload nginx
# get or renew cert
# cert change, reload nginx
#

{{ with (datasource "nginx") }}

    {{ if has . "http" }}
        {{ range .http }}
            {{- if has . "server" }}
                {{- range .server }}
                {{ if has . "server_name" }}
                    server_name {{.server_name}}
                {{ end }}
                {{- end }}
            {{- end }}
        {{ end }}
    {{ end }}

{{ end }}
