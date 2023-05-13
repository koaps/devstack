name := devstack
vol_name := unit_node_modules

.DEFAULT_GOAL := all

vol := $(shell docker volume ls -qf name=${vol_name})

## all target
.PHONY: all
all: build up clean

.PHONY: build
build:
	ansible -e '@.vars.yml' -m template -a "src=gogs/app.ini.j2 dest=gogs/conf/app.ini" localhost
	docker-compose build --pull

## clean target
.PHONY: clean
clean:
	@docker ps -aqf status=exited | xargs -I{} docker rm {}
	@docker images -q -f dangling=true | xargs -I{} docker rmi {}

.PHONY: cleanup
cleanup: down clean
	@docker network rm local || true
	sudo rm -rf /data/devstack

.PHONY: down
down:
	docker-compose -p ${name} down -v

.PHONY: up
up:
	docker network inspect local >/dev/null 2>&1 && true || docker network create --subnet=172.16.16.0/24 local
	@if [ -z "${vol}" ]; then echo -n "creating ${vol_name} volume: "; docker volume create ${vol_name}; fi
	COMPOSE_HTTP_TIMEOUT=300 docker-compose -p ${name} up -d
	ansible-playbook -e '@.vars.yml' --inventory 127.0.0.1, gogs/setup.yml


.PHONY: app
app: app_install app_build app_config

.PHONY: app_install
app_install:
	docker exec -ti -u unit -w /www/fapi_app unit /bin/bash -c "/usr/local/bin/python3 -m venv venv && source venv/bin/activate; pip3 install -U -r requirements.txt"
	docker exec -ti -w /www/node_app unit /bin/bash -c "npm install -g npm@latest"
	docker exec -ti -w /www/node_app unit /bin/bash -c "npm install"
	docker exec -ti -w /www/node_app unit /bin/bash -c "npm link unit-http"

.PHONY: app_build
app_build:
	docker exec -ti -u unit -w /www/node_app unit bash -c "npm run build"

.PHONY: app_config
app_config:
	cp unit/config.json /data/www/config.json
	docker exec -ti unit bash -c "curl -X PUT --data-binary @/www/config.json  \
    --unix-socket /var/run/control.unit.sock  \
    http://localhost/config; rm /www/config.json"


.PHONY: app_restart_node
app_restart_node:
	docker exec -ti unit curl -X GET \
    --unix-socket /var/run/control.unit.sock  \
    http://localhost/control/applications/node/restart

.PHONY: app_restart_fapi
app_restart_fapi:
	docker exec -ti unit curl -X GET \
    --unix-socket /var/run/control.unit.sock  \
    http://localhost/control/applications/fapi/restart
