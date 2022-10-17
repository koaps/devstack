#!/bin/bash

DB=${1:-admin}
USER=${2:-admin}

docker exec -it postgres psql -d $DB -U $USER
