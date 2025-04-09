name := devstack

.DEFAULT_GOAL := all

## all target
.PHONY: all
all: build up clean app_config

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
	sudo rm -rf /home/devstack

.PHONY: down
down:
	docker-compose -p ${name} down -v

.PHONY: push
push:
	docker-compose push

.PHONY: up
up:
	docker network inspect local >/dev/null 2>&1 && true || docker network create --subnet=172.16.16.0/24 local
	COMPOSE_HTTP_TIMEOUT=300 docker-compose -p ${name} up -d
	ansible-playbook -e '@.vars.yml' --inventory 127.0.0.1, gogs/setup.yml


.PHONY: app
app: app_install app_build app_config

.PHONY: app_build
app_build:
	docker exec -ti -u unit -w /www/node_app unit bash -c "npm run build"

.PHONY: app_config
app_config:
	sudo cp unit/config.json /home/${name}/unit/config/
	docker exec -ti unit bash -c "curl -X PUT --data-binary @/docker-entrypoint.d/config.json  \
	--unix-socket /var/run/control.unit.sock http://localhost/config"

.PHONY: app_install
app_install: app_install_fapi app_install_node

.PHONY: app_install_fapi
app_install_fapi:
	docker exec -ti -w /www unit /bin/bash -c "if [ -d fapi_app ]; then rm -rf fapi_app; fi"
	docker exec -ti -w /www unit /bin/bash -c "mkdir fapi_app; chown unit fapi_app"
	docker exec -ti -u unit -w /www/fapi_app unit /bin/bash -c "/usr/local/bin/python3 -m venv venv && source venv/bin/activate; pip3 install -U pip; pip3 install -U -r /www/requirements.txt"

.PHONY: app_install_node
app_install_node:
	docker exec -ti -w /www unit /bin/bash -c "if [ -d node_app ]; then rm -rf node_app; fi"
	docker exec -ti -w /www unit /bin/bash -c "mkdir node_app; chown unit node_app"
	docker exec -ti -w /www/node_app unit /bin/bash -c "npm install -g npm@latest"
	docker exec -ti -w /www/node_app unit /bin/bash -c "npm install"
	docker exec -ti -w /www/node_app unit /bin/bash -c "npm link unit-http"

.PHONY: app_restart_fapi
app_restart_fapi:
	docker exec -ti unit curl -X GET \
	--unix-socket /var/run/control.unit.sock  \
	http://localhost/control/applications/fapi/restart

.PHONY: app_get_config
get_config:
	docker exec -ti unit bash -c "curl --unix-socket /var/run/control.unit.sock http://localhost/config"
