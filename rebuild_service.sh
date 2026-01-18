#!/bin/bash

service="$1"
if [ -z $service ]; then echo "E: need to pass service name"; exit 1; fi

docker-compose -p devstack rm -s $service
docker-compose -p devstack pull $service
docker-compose -p devstack build $service
docker-compose -p devstack up --no-deps -d $service
