#!/usr/bin/env sh

url="http://$GF_SECURITY_ADMIN_USER:$GF_SECURITY_ADMIN_PASSWORD@localhost:3080"

post() {
    curl -s -X POST -d "$1" \
        -H 'Content-Type: application/json;charset=UTF-8' \
        "$url$2" 2> /dev/null
}

run() {
  exec grafana-server                                         \
    --homepath="$GF_PATHS_HOME"                               \
    --config="$GF_PATHS_CONFIG"                               \
    --packaging=docker                                        \
    "$@"                                                      \
    cfg:default.log.mode="console"                            \
    cfg:default.paths.data="$GF_PATHS_DATA"                   \
    cfg:default.paths.logs="$GF_PATHS_LOGS"                   \
    cfg:default.paths.plugins="$GF_PATHS_PLUGINS"             \
    cfg:default.paths.provisioning="$GF_PATHS_PROVISIONING"
}

if [ ! -f "/var/lib/grafana/.init" ]; then
    run $@ &

    until curl -s "$url/api/datasources" 2> /dev/null; do
        sleep 1
    done

    for datasource in /etc/grafana/datasources/*; do
        post "$(envsubst < $datasource)" "/api/datasources"
    done

    touch "/var/lib/grafana/.init"

    kill $(pidof grafana-server)
fi

run
