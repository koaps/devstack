name := devstack

.DEFAULT_GOAL := all

## all target
.PHONY: all
all: build up clean app

.PHONY: build
build:
	ansible -e '@.vars.yml' -m template -a "src=gitea/app.ini.j2 dest=gitea/conf/app.ini" localhost
	docker compose build --pull

## clean target
.PHONY: clean
clean:
	@docker ps -aqf status=exited | xargs -I{} docker rm {}
	@docker images -q -f dangling=true | xargs -I{} docker rmi {}

.PHONY: full_clean_up
cleanup: down clean
	@docker network rm local || true
	sudo rm -rf /home/devstack

.PHONY: down
down:
	docker compose -p ${name} down -v

.PHONY: push
push:
	docker compose push

.PHONY: up
up:
	docker network inspect local >/dev/null 2>&1 && true || docker network create --subnet=172.16.16.0/24 local
	COMPOSE_HTTP_TIMEOUT=300 docker compose -p ${name} up -d
	#ansible-playbook -e '@.vars.yml' --inventory 127.0.0.1, gitea/setup.yml

.PHONY: pull_models
app_get_config:
	docker exec -it ollama_server ollama pull llama3.2:latest
