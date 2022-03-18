#!/bin/bash
# based Vlad Ovchynnykov docs. available in:
# https://pythad.github.io/articles/2016-12/how-to-run-celery-as-a-daemon-in-production

usage() { echo "Usage: $0 [-d <string>] [-c <string>] [-n <string>] [-a <string>]" 1>&2; exit 1; }

while getopts ":d:c:n:a:" o; do
    case "${o}" in
        d)
            CELERY_BIN=${OPTARG}
            ;;
        c)
            CELERYD_CHDIR=${OPTARG}
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

## dirs
BASEDIR_RELATIVE=$(dirname "$0")
cd $BASEDIR_RELATIVE
BASEDIR=$PWD

cd $BASEDIR

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

# copy celeryd config
cp ./assets/celeryd /etc/init.d/celeryd
chmod 755 /etc/init.d/celeryd /var/log/celery/ /var/run/celery/
chown root:root /etc/init.d/celeryd
chown -R root:root /var/log/celery/
chown -R root:root /var/run/celery/

# configure celeryd
touch /etc/default/celeryd

sudo tee /etc/default/celeryd > /dev/null << EOT
CELERY_BIN="${CELERY_BIN}"

# App instance to use
CELERY_APP="${CELERY_APP}"

# Where to chdir at start.
CELERYD_CHDIR="${CELERYD_CHDIR}"

# Extra command-line arguments to the worker
CELERYD_OPTS="--time-limit=300 --concurrency=8"

# %n will be replaced with the first part of the nodename.
CELERYD_LOG_FILE="/var/log/celery/%n%I.log"
CELERYD_PID_FILE="/var/run/celery/%n.pid"

# Workers should run as an unprivileged user.
#   You need to create this user manually (or you can choose
#   a user/group combination that already exists (e.g., nobody).
CELERYD_USER="root"
CELERYD_GROUP="root"

# If enabled pid and log directories will be created if missing,
# and owned by the userid/group configured.
CELERY_CREATE_DIRS=1

export SECRET_KEY="foobar"
EOT

# celerybeat

touch /etc/default/celeryd

sudo tee /etc/default/celeryd > /dev/null << EOT
CELERY_BIN="${CELERY_BIN}"

# App instance to use
CELERY_APP="${CELERY_APP}"

# Where to chdir at start.
CELERYD_CHDIR="${CELERYD_CHDIR}"

# Extra command-line arguments to the worker
CELERYD_OPTS="--time-limit=300 --concurrency=8"

# %n will be replaced with the first part of the nodename.
CELERYD_LOG_FILE="/var/log/celery/%n%I.log"
CELERYD_PID_FILE="/var/run/celery/%n.pid"

# Workers should run as an unprivileged user.
#   You need to create this user manually (or you can choose
#   a user/group combination that already exists (e.g., nobody).
CELERYD_USER="root"
CELERYD_GROUP="root"

# If enabled pid and log directories will be created if missing,
# and owned by the userid/group configured.
CELERY_CREATE_DIRS=1

export SECRET_KEY="foobar"
EOT

# celerybeat
cp ./assets/celerybeat /etc/init.d/celerybeat

chmod 755 /etc/init.d/celerybeat
chown root:root /etc/init.d/celerybeat

# As vlad says
# "Configure it depending on what you need. Options and template can be fount in the docs in: http://docs.celeryproject.org/en/latest/userguide/daemonizing.html#init-script-celerybeat"
# start daemons

/etc/init.d/celeryd stop
/etc/init.d/celerybeat stop
/etc/init.d/celeryd start
/etc/init.d/celerybeat start
# make the init.d services startup
update-rc.d celeryd defaults
update-rc.d celerybeat defaults


printf "
\033[0;32m
use this commands to manage \`celery\` and \`celerybeat\` daemons respectively
/etc/init.d/celeryd {start|stop|restart}
/etc/init.d/celerybeat {start|stop|restart}
\033[0m
"
