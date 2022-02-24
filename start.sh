#!/bin/bash

usage() { echo "Usage: $0 [-d <string>] [-c <string>] [-n <string>] [-a <string>]" 1>&2; exit 1; }

while getopts ":d:c:n:a:" o; do
    case "${o}" in
        d)
            celeryDir=${OPTARG}
            ;;
        c)
            projectCHDir=${OPTARG}
            ;;
        n)
            projectName=${OPTARG}
            ;;
        a)
            CELERY_APP=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

echo "CELERY_APP = ${CELERY_APP}"

# update the repos
sudo apt-get update

# base configure

sudo groupadd celery
sudo useradd -g celery celery

# install requirements
pip3 install celery
pip3 install Redis

# install redis

# based digitalOcean article
# https://www.digitalocean.com/community/tutorials/how-to-install-and-secure-redis-on-ubuntu-18-04
sudo apt install redis-server

CONFIG_FILE=/etc/redis/redis.conf
sed -i '/supervised */c\supervised no' $CONFIG_FILE

sudo systemctl restart redis.service

# install and configure celery
mkdir /var/log/celery
touch /etc/default/celeryd
mkdir /var/run/celery

sudo tee /etc/default/celeryd > /dev/null << EOT
#   most people will only start one node:
CELERYD_NODES="worker1 worker2 worker3"
#   but you can also start multiple and configure settings
#   for each in CELERYD_OPTS
#CELERYD_NODES="worker1 worker2 worker3"
#   alternatively, you can specify the number of nodes to start:
#CELERYD_NODES=10

# Absolute or relative path to the 'celery' command:
CELERY_BIN="${celeryDir}"

# App instance to use
# comment out this line if you don't use an app
## CELERY_APP="celery_app_name"
# or fully qualified:
CELERY_APP="${CELERY_APP}"

# Where to chdir at start.
CELERYD_CHDIR="${projectCHDir}"

# Extra command-line arguments to the worker
CELERYD_OPTS="--time-limit=300 --concurrency=8"
# Configure node-specific settings by appending node name to arguments:
#CELERYD_OPTS="--time-limit=300 -c 8 -c:worker2 4 -c:worker3 2 -Ofair:worker1"

# Set logging level to DEBUG
#CELERYD_LOG_LEVEL="DEBUG"

# %n will be replaced with the first part of the node name.
CELERYD_LOG_FILE="/var/log/celery/%n%I.log"
CELERYD_PID_FILE="/var/run/celery/%n.pid"

# Workers should run as an unprivileged user.
#   You need to create this user manually (or you can choose
#   a user/group combination that already exists (e.g., nobody).
CELERYD_USER="celery"
CELERYD_GROUP="celery"
CELERYD_LOG_LEVEL="INFO"
# If enabled PID and log directories will be created if missing,
# and owned by the userid/group configured.
CELERY_CREATE_DIRS=1
EOT

## configure celery beat

sudo tee /etc/default/celerybeat > /dev/null << EOT
# Absolute or relative path to the 'celery' command:
CELERY_BIN="${celeryDir}"

# App instance to use
# comment out this line if you don't use an app
CELERY_APP="${CELERY_APP}"
# or fully qualified:
#CELERY_APP="${CELERY_APP}"

# Where to chdir at start.
CELERYBEAT_CHDIR="${projectCHDir}"

# Extra arguments to celerybeat
CELERYBEAT_OPTS="--schedule=/var/run/celery/celerybeat-schedule"

CELERYBEAT_LOG_FILE="/var/log/celery/beat-%n%I.log"
CELERYBEAT_PID_FILE="/var/run/celery/beat-%n.pid"
EOT

# change the owner of the log dirs
chown -R celery:celery /var/log/celery/
chown -R celery:celery /var/run/celery/

# creating the systemd file
# here will will create both systemd files for 
# celery worker and beat
touch /etc/systemd/system/celery.service

sudo tee /etc/systemd/system/celery.service > /dev/null << EOT
[Unit]
Description=Celery Service
After=network.target

[Service]
Type=forking
User=celery
Group=celery

EnvironmentFile=/etc/default/celeryd
WorkingDirectory=${projectCHDir}
ExecStart=${celeryDir} multi start \${CELERYD_NODES} \
  -A \${CELERY_APP} --pidfile=\${CELERYD_PID_FILE} \
  --logfile=\${CELERYD_LOG_FILE} --loglevel=\${CELERYD_LOG_LEVEL} \${CELERYD_OPTS}
ExecStop=${celeryDir} \${CELERY_BIN} multi stopwait \${CELERYD_NODES} \
  --pidfile=\${CELERYD_PID_FILE}
ExecReload=${celeryDir} \${CELERY_BIN} multi restart \${CELERYD_NODES} \
  -A \${CELERY_APP} --pidfile=\${CELERYD_PID_FILE} \
  --logfile=\${CELERYD_LOG_FILE} --loglevel=\${CELERYD_LOG_LEVEL} \${CELERYD_OPTS}

[Install]
WantedBy=multi-user.target
EOT

sudo tee /etc/systemd/system/celerybeat.service > /dev/null << EOT
[Unit]
Description=Celery Beat Service
After=network.target

[Service]
Type=simple
User=celery
Group=celery
EnvironmentFile=/etc/default/celerybeat
WorkingDirectory=${projectCHDir}
ExecStart=/bin/sh -c '\${CELERY_BIN} -A \${CELERY_APP} beat  \
    --pidfile=\${CELERYBEAT_PID_FILE} \
    --logfile=\${CELERYBEAT_LOG_FILE} --loglevel=\${CELERYD_LOG_LEVEL}'
Restart=always

[Install]
WantedBy=multi-user.target
EOT


sudo systemctl daemon-reload
sudo systemctl enable celery
sudo systemctl enable celerybeat
sudo systemctl restart celery
sudo systemctl restart celerybeat

## You can test it using this command
## celery -A CELERY_APP_NAME worker -l INFO