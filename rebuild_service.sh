#!/bin/bash

service="$1"
if [ -z $service ]; then echo "E: need to pass service name"; exit 1; fi

docker-compose rm -s $service
docker-compose build $service
docker-compose up -d $service
