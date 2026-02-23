#!/bin/bash

CONF_DIR=/home/devstack/kanidm

if [ ! -f $HOME/.cache/kanidm_tokens ]; then
  echo '{}' > $HOME/.cache/kanidm_tokens
  chmod 666 $HOME/.cache/kanidm_tokens
fi
if [ ! -f $HOME/.config/kanidm ]; then
  cat >$HOME/.config/kanidm<<EOF
uri = "https://localhost:8443"
verify_ca = false
EOF
fi
if [ -z "docker images kanidm/tools:latest -q" ]; then
  docker pull kanidm/tools:latest
fi
docker run -it --rm \
    --network host \
    --mount "type=bind,src=$CONF_DIR,target=/data:ro" \
    --mount "type=bind,src=$HOME/.config/kanidm,target=/root/.config/kanidm" \
    --mount "type=bind,src=$HOME/.cache/kanidm_tokens,target=/root/.cache/kanidm_tokens" \
    kanidm/tools:latest \
    /sbin/kanidm "$@"
