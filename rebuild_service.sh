#!/bin/bash

compose="docker compose"
project=devstack
service="$1"
if [ -z $service ]; then echo "E: need to pass service name"; exit 1; fi

$compose -p $project rm -sf $service
$compose -p $project pull $service
$compose -p $project build $service
$compose -p $project up --no-deps -d $service
