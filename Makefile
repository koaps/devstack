.POSIX:
.PHONY: *
.EXPORT_ALL_VARIABLES:

.DEFAULT_GOAL := all

CONTAINERD_SNAPSHOTTER=zfs

name := devstack

all: build up

build:
	ansible -e '@.vars.yml' -m template -a "src=gitea/app.ini.j2 dest=gitea/conf/app.ini" localhost
	docker compose build

clean:
	@docker ps -aqf status=exited | xargs -I{} docker rm {}
	@docker images -q -f dangling=true | xargs -I{} docker rmi {}

full_cleanup: down clean
	@docker network rm local || true
	sudo rm -rf /home/devstack

down:
	docker compose -p ${name} down -v

push:
	docker compose push

up:
	docker network inspect local >/dev/null 2>&1 && true || docker network create --subnet=172.16.16.0/24 local
	COMPOSE_HTTP_TIMEOUT=300 docker compose -p ${name} up -d
	#ansible-playbook -e '@.vars.yml' --inventory 127.0.0.1, gitea/setup.yml

pull_models:
	docker exec -it ollama_server ollama pull llama3.2:latest
