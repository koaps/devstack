DevStack
========

This the local development environment I run on my home server, it's just a way to organize compose files to make it easy to add new services as needed for devops type of setups (CICD, git/db/web servers, docker and pip registries, TIG stack monitoring).

You can re-run make fairly safely to push updates and changes since it uses external volumes that survive a compose down, but if you are keeping anything important to you in any of the services, I would back them up somewhere just in-case.

### Requires:
* Linux
* Ansible
* Containerd

**Note: I'm running this on a 12-core Debian machine with 32G ram and ZFS volumes, the monitoring stack eats a lot of memory, so comment it out if the overhead is too much, the influxdb and telegraf settings might need to be tweaked for better performance and feel free to PR any improvements you find.**

### Create the `.env` file:
Replace `<YOUR_SERVER_IP>` with the ip of your docker server

```
SERVER_IP=<YOUR_SERVER_IP>

cat >.env<<EOF
DEVSTACK_DIR=/home/devstack
AUTH_HOST=${SERVER_IP}
AUTH_DOMAIN=auth.local.domain
DRONE_COOKIE_SECRET=some-random-words-here
DRONE_DATABASE_DRIVER=postgres
DRONE_DATABASE_SOURCE=postgres://drone:drone@postgres:5432/drone?sslmode=disable
DRONE_GITEA_SERVER=http://gitea:3000
DRONE_RPC_SECRET=derpy-derp-derp
DRONE_UI_PASSWORD=adm1n
DRONE_UI_USERNAME=admin
GRAFANA_ADMIN_PASS=adm1n
GRAFANA_ADMIN_USER=admin
INFLUX_DB_BUCKET=telegraf
INFLUX_DB_ORG=null
INFLUX_DB_TOKEN=<Created Token>
INFLUX_DB_PASSWORD=influxdb
INFLUX_DB_USER=admin
PGADMIN_EMAIL=admin@local.host
PGADMIN_PASS=adm1n
EOF

cat >.vars.yml<<EOF
gitea_domain: ${SERVER_IP}
gitea_root_url: http://${SERVER_IP}:3000
gitea_secret_key: derp-derpy-derp
gitea_url: 127.0.0.1:3000
gitea_user: admin
gitea_pass: adm1n
gitea_db_type: postgres
gitea_db_host: postgres:5432
gitea_db_name: gitea
gitea_db_user: gitea
gitea_db_pass: gitea
kanidm_domain: local.domain
kanidm_origin: https://auth.local.domain:8443
EOF
```

### Database passwords
The DB password for gitea and drone is set via the initdb sql files, change them there if changing the vars above.

### To create the devstack
* Build the images and run containers:
  ```
  make

  docker compose ps
  ```

### To stop the devstack
* Just run make down
  ```
  make down
  ```

## TODO: Script these commands ##

### Recover Logins for Kanidm
```
docker exec -it kanidm kanidmd recover-account admin
docker exec -i -t kanidm kanidmd recover-account idm_admin
```

### Add Kanidm CA cert to Gitea (OAuth will fail without this)
```
docker cp /home/devstack/kanidm/ca.pem gitea:/usr/local/share/ca-certificates/kanidm.ca.crt
docker exec gitea update-ca-certificates
docker restart gitea
```

### Create Kanidm User
```
./kanidm_client.sh person create koaps Koaps
./kanidm_client.sh person update koaps -m koaps@local.domain
./kanidm_client.sh person credential create-reset-token koaps
./kanidm_client.sh person credential use-reset-token xxxxx-xxxxx-xxxxx-xxxxx
```
#### Set a password and setup TOTP with an authenicator app, commit the changes

### Create Kanidm OAuth for Gitea (replace SERVER_IP)
Ref: https://kanidm.github.io/kanidm/stable/integrations/oauth2/examples.html#gitea
```
./kanidm_client.sh group create gitea_users
./kanidm_client.sh group add-members gitea_users koaps
./kanidm_client.sh system oauth2 create gitea Gitea http://${SERVER_IP}:3000/user/login
./kanidm_client.sh system oauth2 add-redirect-url gitea http://${SERVER_IP}:3000/user/oauth2/kanidm/callback
./kanidm_client.sh system oauth2 update-scope-map gitea gitea_users email openid profile groups
./kanidm_client.sh system oauth2 warning-insecure-client-disable-pkce gitea
./kanidm_client.sh system oauth2 show-basic-secret gitea
```

### Add OAuth to Gitea (replace show-basic-secret and dicovery url)
```
docker exec gitea su -l git -c '/app/gitea/gitea -c /data/gitea/conf/app.ini admin auth add-oauth \
    --provider=openidConnect \
    --name=kanidm \
    --key=gitea \
    --secret=show-basic-secret \
    --auto-discover-url=https://auth.local.domain:8443/oauth2/openid/gitea/.well-known/openid-configuration'
```

### To create a token for grafana and telegraf
* Create an api token
  ```
  docker exec -it influxdb influx auth create --org null --all-access -d apitoken
  ```

* Update .env file INFLUX_DB_TOKEN value

* Rebuild grafana and telegraf
  ```
  ./rebuild_service.sh grafana
  ./rebuild_service.sh telegraf
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
index-url=http://172.16.16.1:9888/simple
trusted-host=172.16.16.1
```
This is the internal gateway IP of the docker server, it should work fine for anything in the devstack network.

Just note that any updates to the packages on disk (mirroring) requires the pypi-server to be restarted.

### Service URLs
```
$ export SERVER_IP=X.X.X.X
$ cat <<EOC
# Unit Server (static)
http://${SERVER_IP}/

# Gitea UI
http://${SERVER_IP}:3000/

# Grafana UI
http://${SERVER_IP}:3080/

# Registry API
http://${SERVER_IP}:5000/

# Registry UI
http://${SERVER_IP}:5080/

# pgAdmin - Postgres admin ui
http://${SERVER_IP}:5480/

# K3s API
http://${SERVER_IP}:6443/

# Drone Server - CICD, you need to enable and trust repos for them to build
http://${SERVER_IP}:7300/

# Selenium Server
http://${SERVER_IP}:7444/

# Influxdb - has dashboards you can use to see monitoring datta
http://${SERVER_IP}:8086/

# Kanidm UI
http://${SERVER_IP}:8443/

# Ollama WebUI
http://${SERVER_IP}:9780/

# PIP Packages
http://${SERVER_IP}:9888/packages/
EOC
```
