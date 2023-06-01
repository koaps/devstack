DevStack
========

This the local development environment I run on my home server, right now I'm using it for learning some javascript, but it's just a way to organize docker-compose to make it easy to add new services as needed for devops type of setups (CICD, git/db/web servers, docker and pip registries, TIG stack monitoring).

You can re-run make fairly safely to push updates and changes since it uses external volumes that survive a docker-compose down, but if you are keeping anything important to you in any of the services, I would back them up somewhere just in-case.

### Requires:
* Linux
* Ansible
* Docker
* InfluxDB Cli
* Python3

**Note: I'm running this on a 12core Debian machine with 32G ram, docker eats a lot of memory running the monitoring stack, so I have commented it out because of the overhead, the influxdb and telegraf settings might need to be tweaked for better performance and feel free to PR any improvements you find.**

First create an influxdb token, see [here](https://docs.influxdata.com/influxdb/cloud/reference/cli/influx/auth/create/)

Also change the InfluxDB Org name below if you want.

### Create the env files:
Replace `<YOUR_SERVER_IP>` with the ip of your docker server

```
$ SERVER_IP=<YOUR_SERVER_IP>

$ cat >.env<<EOF
DEVSTACK_DIR=/opt/devstack
DRONE_DATABASE_DRIVER=postgres
DRONE_DATABASE_SOURCE=postgres://drone:drone@postgres:5432/drone?sslmode=disable
DRONE_GOGS_SERVER=http://gogs:3000
DRONE_RPC_SECRET=derpy-derp-derp
GOGS_ADMIN=gadmin
GRAFANA_ADMIN_PASS=adm1n
INFLUX_ORG=null
INFLUX_TOKEN=<TOKEN_FROM_INFLUX>
INFLUX_URL=http://${SERVER_IP}:8086
NGINX_HOST=${SERVER_IP}
PGADMIN_EMAIL=admin@local.host
PGADMIN_PASS=adm1n
EOF

$ cat >.vars.yml<<EOF
gogs_domain: ${SERVER_IP}
gogs_pass: gadm1n
gogs_root_url: http://${SERVER_IP}:3000
gogs_secret_key: derp-derpy-derp
gogs_url: 127.0.0.1:3000
gogs_user: gadmin
EOF
```


### Database passwords
The DB password for gogs and drone is set via the initdb sql files, change them there if changing the vars above.


### To create the devstack
* Build the images and run containers:
  ```
  $ make

  $ docker-compose ps
         Name                    Command                  State                                                              Ports
    --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    drone_runner      /bin/drone-runner-docker         Up             0.0.0.0:8300->3000/tcp,:::8300->3000/tcp
    drone_server      /bin/drone-server                Up             0.0.0.0:8443->443/tcp,:::8443->443/tcp, 0.0.0.0:8000->80/tcp,:::8000->80/tcp
    gogs              /app/gogs/docker/start.sh  ...   Up (healthy)   0.0.0.0:3022->22/tcp,:::3022->22/tcp, 0.0.0.0:3000->3000/tcp,:::3000->3000/tcp
    pgadmin           /entrypoint.sh                   Up             443/tcp, 0.0.0.0:5050->80/tcp,:::5050->80/tcp
    postgres          /entrypoint.sh postgres          Up             0.0.0.0:5432->5432/tcp,:::5432->5432/tcp
    pypi_server       /entrypoint.sh -P . -a . - ...   Up             0.0.0.0:9000->8080/tcp,:::9000->8080/tcp
    registry          /entrypoint.sh /etc/docker ...   Up             0.0.0.0:5000->5000/tcp,:::5000->5000/tcp
    registry-ui       /docker-entrypoint.sh ngin ...   Up             0.0.0.0:5080->80/tcp,:::5080->80/tcp
    selenium_server   /opt/bin/entry_point.sh          Up             0.0.0.0:4444->4444/tcp,:::4444->4444/tcp, 5900/tcp, 0.0.0.0:7900->7900/tcp,:::7900->7900/tcp
    unit              /usr/local/bin/docker-entr ...   Up             0.0.0.0:80->80/tcp,:::80->80/tcp, 0.0.0.0:8080->8080/tcp,:::8080->8080/tcp, 0.0.0.0:9090->9090/tcp,:::9090->9090/tcp
  ```

* Run NodeJS app build
  ```
  $ make build
  ```

* Configure the unit server
  ```
  $ make config
  ```
  if there's an error, you can check the container logs:
  ```
  $ docker logs unit -f
  ```
  or exec into the container and look around:
  ```
  $ docker exec -ti -w /www unit /bin/bash
  root@unit:/www# su - unit
  unit@unit:~$
  ```

* Restart Unit Apps (as needed)
  The unit apps will need to be restarted if using a mount and the code is changed on disk.
  ```
  # nodejs
  $ make app_restart_node

  # fastapi
  $ make app_restart_fapi
  ```


### Mirroring
I recommend using [pypi-mirror](https://github.com/koaps/pypi-mirror) to populate the pypi server with any requirements you might have, this will save you some downloading when recreating containers.

I create a container with the following mounts:
```
/opt/devstack/packages:/data/packages
/opt/pypi_mirror/pip_dir:/root/.cache/pip
/opt/pypi_mirror/tmp_dir:/tmp
```
This mounts the packages dir used by the pypi_server

Also copy over a requirements.txt with a list of pip packages you want to mirror, pypy-miror will pull the dependancies, so you don't need to be overly explict about stuff unless you want particular versions.

Now exec into the container (or setup an entrypoint script) and run the pypi-mirror like this:
```
$ cd /data
$ pypi-mirror download -d packages -r requirements.txt
$ pypi-mirror create -d packages -m simple
```

Now whereever you need to install pip packages use a pip.conf like this:
```
[global]
index-url=http://172.16.16.1:9000/simple
trusted-host=172.16.16.1
```
This is the internal gateway IP of the docker server, it should work fine for anything in the devstack network.

### Service URLs
```
$ export SERVER_IP=X.X.X.X
$ cat <<EOC
# Unit Server (static)
http://${SERVER_IP}/

# Gogs UI
http://${SERVER_IP}:3000/

# Selenium Server
http://${SERVER_IP}:4444/

# pgAdmin - Postgres admin ui
http://${SERVER_IP}:5050/

# Docker Registry
http://${SERVER_IP}:5080/

# Drone Server - CICD, you need to enable and trust repos for them to build
http://${SERVER_IP}:8000/

# MongoDB Express UI
http://${SERVER_IP}:8081/

# Influxdb - has dashboards you can use to see monitoring datta
http://${SERVER_IP}:8086/

# PIP Packages
http://${SERVER_IP}:9000/packages/

# Unit Server (express)
http://${SERVER_IP}:9080/

# Unit Server (fastapi)
http://${SERVER_IP}:9090/
EOC
```
