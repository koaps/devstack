.POSIX:
.PHONY: *
.EXPORT_ALL_VARIABLES:

.DEFAULT_GOAL := all

CONTAINERD_SNAPSHOTTER=zfs

name := devstack

# Using nerdctl for container management
cmd := sudo -E nerdctl

all: build up clean app

build:
	ansible -e '@.vars.yml' -m template -a "src=gitea/app.ini.j2 dest=gitea/conf/app.ini" localhost
	${cmd} compose build --pull

clean:
	@${cmd} ps -aqf status=exited | xargs -I{} ${cmd} rm {}
	@${cmd} images -q -f dangling=true | xargs -I{} ${cmd} rmi {}

full_cleanup: down clean
	@${cmd} network rm local || true
	sudo rm -rf /home/devstack

down:
	${cmd} compose -p ${name} down -v

push:
	${cmd} compose push

up:
	${cmd} network inspect local >/dev/null 2>&1 && true || ${cmd} network create --subnet=172.16.16.0/24 local
	COMPOSE_HTTP_TIMEOUT=300 ${cmd} compose -p ${name} up -d
	#ansible-playbook -e '@.vars.yml' --inventory 127.0.0.1, gitea/setup.yml

pull_models:
	${cmd} exec -it ollama_server ollama pull llama3.2:latest
