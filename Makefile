.POSIX:
.PHONY: *
.EXPORT_ALL_VARIABLES:

.DEFAULT_GOAL := all

all: build up

build:
	docker compose build

clean:
	@docker ps -aqf status=exited | xargs -I{} docker rm {}
	@docker images -q -f dangling=true | xargs -I{} docker rmi {}

full_cleanup: down clean
	@docker network rm local || true
	sudo rm -rf /home/devstack

down:
	docker compose -p devstack down -v

push:
	docker compose push

up:
	docker network inspect local >/dev/null 2>&1 && true || docker network create --subnet=172.16.16.0/24 local
	ansible-playbook -e '@vars.yml' --inventory 127.0.0.1, setup.yml
	COMPOSE_HTTP_TIMEOUT=300 docker compose -p devstack up -d
	ansible-playbook -e '@vars.yml' --inventory 127.0.0.1, gitea/setup.yml

pull_models:
	docker exec -it ollama_server ollama pull llama3.2:latest
