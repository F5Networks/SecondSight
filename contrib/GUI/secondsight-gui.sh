#!/bin/bash

#
# Usage
#
usage() {
BANNER="Second Sight GUI - https://github.com/F5Networks/SecondSight/\n\n
This script is used to deploy/undeploy Second Sight GUI\n\n
=== Usage:\n\n
$0 [-h | -c <action> [-s -C cert.pem -K key.pem -B bundle.pem] | -x]\n\n
=== Options:\n\n
-h\t\t\t\t\t\t- This help\n
-c [start|stop|restart|deploy|undeploy]\t- Deployment command\n
-x\t\t\t\t\t\t- Remove backend persistent data\n\n
-s\t\t\t\t\t\t- Publish the GUI using HTTPS (requires cert and key)\n
-C [cert.pem]\t\t\t\t\t- TLS certificate file in .pem format (mandatory with -s)\n
-K [key.pem]\t\t\t\t\t- TLS key file in .pem format (mandatory with -s)\n
-B [bundle.pem]\t\t\t\t- TLS bundle/chain file in .pem format (mandatory with -s)\n\n
=== Examples:\n\n
Deploy HTTPS GUI with Docker compose:\t$0 -c start -s -C certfile.pem -K keyfile.pem -B bundle.pem\n
Remove GUI from Docker compose:\t$0 -c stop\n
Restart and update docker images:\t$0 -c restart\n\n
Deploy HTTP GUI on Linux VM:\t\t$0 -c deploy\n
Remove GUI from Linux VM:\t\t$0 -c undeploy\n\n
Remove backend data:\t\t\t$0 -x\n
"

echo -e $BANNER 2>&1
exit 1
}

#
# Second Sight GUI deployment
#
gui_start() {
echo "-> Deploying Second Sight GUI with docker-compose"

if [ $# == 3 ]
then
	# Deploying in HTTPS mode
	YAML_FILE=$DOCKER_COMPOSE_YAML_HTTPS
	CERT_FILE=$1
	KEY_FILE=$2
	BUNDLE_FILE=$3
	cp $CERT_FILE ssl/secondsight.crt
	cp $KEY_FILE ssl/secondsight.key
	cp $BUNDLE_FILE ssl/secondsight.chain
else
	# Deploying in HTTP mode
	YAML_FILE=$DOCKER_COMPOSE_YAML_HTTP
fi

docker-compose -f $YAML_FILE pull
COMPOSE_HTTP_TIMEOUT=240 docker-compose -p $PROJECT_NAME -f $YAML_FILE up -d --remove-orphans
}

#
# Second Sight GUI removal
#
gui_stop() {
echo "-> Undeploying Second Sight GUI with docker-compose"

if [ $# == 3 ]
then
	# Undeploying in HTTPS mode
	YAML_FILE=$DOCKER_COMPOSE_YAML_HTTPS
else
	# Undeploying in HTTP mode
	YAML_FILE=$DOCKER_COMPOSE_YAML_HTTP
fi

COMPOSE_HTTP_TIMEOUT=240 docker-compose -p $PROJECT_NAME -f $YAML_FILE down
}

gui_restart() {
echo "-> Restarting and updating Second Sight GUI with docker-compose"
gui_stop
gui_start
}

gui_deploy() {
export PGPASSWORD=admin
PG_USER=secondsight
PG_DB=secondsight
PG_HOST=postgres
SECONDSIGHT_RELEASE=4.9.9
JARFILE_URL=https://github.com/F5Networks/SecondSight/releases/download/$SECONDSIGHT_RELEASE/secondsight.jar

echo "-> Deploying Second Sight GUI on virtual machine"
check_root
check_distro
case $distro in
	'ubuntu-22')
		export DEBIAN_FRONTEND=noninteractive

		# Names resolution
		echo "127.0.0.1 postgres f5tt" >> /etc/hosts

		# Packages
		PACKAGES="postgresql-14 openjdk-18-jre nginx python3-pip ttf-mscorefonts-installer"
		apt update
		apt -y install $PACKAGES

		# Configuration files
		mkdir -p /opt/secondsight/contrib
		ln -s /opt/secondsight /app
		cp etc/secondsight.properties /app/

		# F5tt
		cp -av ../bigiq-collect /app/contrib/
		cp -av ../../f5tt /app/
		pip install -r /app/f5tt/requirements.txt

		cp vm/ubuntu22/f5tt-start.sh /app/contrib/bigiq-collect/
		chmod +x /app/contrib/bigiq-collect/f5tt-start.sh
		cp vm/ubuntu22/f5tt.service /etc/systemd/system/
		systemctl enable f5tt
		systemctl start f5tt

		# PostgreSQL init
		cat psql/psql-init.sql | sudo -i -u postgres psql
		cat psql/psql-schema.sql | psql -U $PG_USER -h $PG_HOST $PG_DB
		cat psql/psql-data.sql | psql -U $PG_USER -h $PG_HOST $PG_DB

		# GUI init
		wget -nd $JARFILE_URL -O /app/secondsight.jar
		cp vm/ubuntu22/secondsight.service /etc/systemd/system/
		systemctl enable secondsight
		systemctl start secondsight

		# NGINX init
		if [ $# == 3 ]
		then
			# Deploying in HTTPS mode
			CERT_FILE=$1
			KEY_FILE=$2
			BUNDLE_FILE=$3
			mkdir -p /etc/ssl
			cp $CERT_FILE /etc/ssl/secondsight.crt
			cp $KEY_FILE /etc/ssl/secondsight.key
			cp $BUNDLE_FILE /etc/ssl/secondsight.chain
			cp nginx/secondsight-gui-https.conf /etc/nginx/conf.d/
		else
			# Deploying in HTTP mode
			cp nginx/secondsight-gui-http.conf /etc/nginx/conf.d/
		fi

		rm /etc/nginx/sites-enabled/*
		nginx -s reload
	;;
	*)
		echo "Error: this Linux distribution is not currently supported"
		exit
	;;
esac
}

gui_undeploy() {
echo "-> Deploying Second Sight GUI on virtual machine"
check_root
check_distro
case $distro in
	'ubuntu-22')
		systemctl stop secondsight
		systemctl disable secondsight
		rm /etc/systemd/system/secondsight.service

		systemctl stop f5tt
		systemctl disable f5tt
		rm /etc/systemd/system/f5tt.service

		PACKAGES="postgresql-14 openjdk-18-jre nginx python3-pip ttf-mscorefonts-installer"
		apt -y remove $PACKAGES

		rm /app /etc/nginx/conf.d/secondsight-gui.conf /etc/ssl/secondsight.*
		rm -r /opt/secondsight
	;;
	*)
		echo "Error: this Linux distribution is not currently supported"
		exit
	;;
esac
}

check_root() {
if [ "`whoami`" != "root" ]
then
	echo "This operation requires the script to be run as root"
	exit
fi
}

check_distro() {
    if command -V lsb_release >/dev/null 2>&1; then
        os=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
        codename=$(lsb_release -cs | tr '[:upper:]' '[:lower:]')
        release=$(lsb_release -rs | sed 's/\..*$//')

        if echo "$os" | grep -i "redhatenterprise" >/dev/null 2>&1; then
            os="redhatenterprise"
            centos_flavor="red hat linux"
        elif [ "$os" = "oracleserver" ]; then
            os="centos"
            centos_flavor="oracle linux server"
        fi
    # Try other methods to determine OS
    else
        if ls /etc/*-release >/dev/null 2>&1; then

            os=$(cat /etc/*-release | grep '^ID=' |
                sed 's/^ID=["]*\([a-zA-Z]*\).*$/\1/' |
                tr '[:upper:]' '[:lower:]')

            if [ "$os" = "rhel" ]; then
                os="redhatenterprise"
                centos_flavor="red hat linux"
            fi

            if [ -z "$os" ]; then
                if grep -i "oracle linux" /etc/*-release ||
                    grep -i "red hat" /etc/*-release; then
                    os="redhatenterprise"
                elif grep -i "centos" /etc/*-release; then
                    os="centos"
                else
                    os="linux"
                fi
            fi
        else
            os=$(uname -s | tr '[:upper:]' '[:lower:]')
        fi

        case "$os" in
            ubuntu)
                codename=$(cat /etc/*-release | grep '^DISTRIB_CODENAME' |
                    sed 's/^[^=]*=\([^=]*\)/\1/' |
                    tr '[:upper:]' '[:lower:]')
                ;;
            debian)
                codename=$(cat /etc/*-release | grep '^VERSION=' |
                    sed 's/.*(\(.*\)).*/\1/' |
                    tr '[:upper:]' '[:lower:]')
                ;;
            centos)
                codename=$(cat /etc/*-release | grep -i 'centos.*(' |
                    sed 's/.*(\(.*\)).*/\1/' | head -1 |
                    tr '[:upper:]' '[:lower:]')
                # For CentOS grab release
                release=$(cat /etc/*-release | grep -i 'centos.*[0-9]' |
                    sed 's/^[^0-9]*\([0-9][0-9]*\).*$/\1/' | head -1)
                ;;
            redhatenterprise)
                centos_flavor="red hat linux"
                codename=$(cat /etc/*-release | grep -i 'red hat.*(' |
                    sed 's/.*(\(.*\)).*/\1/' | head -1 |
                    tr '[:upper:]' '[:lower:]')
                # For Red Hat also grab release
                release=$(cat /etc/*-release | grep -i 'red hat.*[0-9]' |
                    sed 's/^[^0-9]*\([0-9][0-9]*\).*$/\1/' | head -1)

                if [ -z "$release" ]; then
                    release=$(cat /etc/*-release | grep -i '^VERSION_ID=' |
                        sed 's/^[^0-9]*\([0-9][0-9]*\).*$/\1/' | head -1)
                fi
                ;;
            ol)
                os="centos"
                centos_flavor="red hat linux"
                codename=$(cat /etc/*-release | grep -i 'red hat.*(' |
                    sed 's/.*(\(.*\)).*/\1/' | head -1 |
                    tr '[:upper:]' '[:lower:]')
                # For Red Hat also grab release
                release=$(cat /etc/*-release | grep -i 'red hat.*[0-9]' |
                    sed 's/^[^0-9]*\([0-9][0-9]*\).*$/\1/' | head -1)

                if [ -z "$release" ]; then
                    release=$(cat /etc/*-release | grep -i '^VERSION_ID=' |
                        sed 's/^[^0-9]*\([0-9][0-9]*\).*$/\1/' | head -1)
                fi
                ;;
            amzn)
                os="amazon"
                centos_flavor="amazon linux"
                codename="amazon-linux-ami"

                amzn=$(rpm --eval "%{amzn}")
                release=${amzn}
                if [ "${amzn}" = 1 ]; then
                    release="latest"
                fi
                ;;
            freebsd)
                os="freebsd"
                release=$(cat /etc/*-release | grep -i '^VERSION_ID=' |
                    sed 's/^[^0-9]*\([0-9][0-9]*\).*$/\1/' | head -1)
                ;;
            sles | suse)
                os="suse"
                release=$(cat /etc/*-release | grep -i '^VERSION_ID=' |
                    sed 's/^[^0-9]*\([0-9][0-9]*\).*$/\1/' | head -1)
                ;;
            *)
                err_exit "Unsupported operating system '$os'"
                codename=""
                release=""
        esac
    fi

    distro=$os-$release
    #printf "%s-%s %s\n" "$os" "$release" "$centos_flavor"
    echo "-> Running on $distro"
}

#
# Main
#

DOCKER_COMPOSE_YAML_HTTP=secondsight-gui-http.yaml
DOCKER_COMPOSE_YAML_HTTPS=secondsight-gui-https.yaml
PROJECT_NAME=secondsight-gui

while getopts 'hc:sC:K:B:x' OPTION
do
        case "$OPTION" in
                h)
			usage
                ;;
                c)
                        ACTION=$OPTARG
                ;;
		s)
			HTTPS_ENABLED="true"
		;;
		C)
			TLS_CERT_FILENAME=$OPTARG
		;;
		K)
			TLS_KEY_FILENAME=$OPTARG
		;;
		B)
			TLS_BUNDLE_FILENAME=$OPTARG
		;;
		x)
			echo "-> Removing backend persistent data"
			docker volume rm secondsight-gui_postgres_data
			exit
                ;;
        esac
done

if [ -z "${ACTION}" ] || [[ ! "${ACTION}" == +(start|stop|restart|deploy|undeploy) ]]
then
	usage
fi

if [ ! -z "${HTTPS_ENABLED}" ] && ([ -z "${TLS_CERT_FILENAME}" ] || [ -z "${TLS_KEY_FILENAME}" ] || [ -z "${TLS_BUNDLE_FILENAME}" ])
then
	usage
fi

gui_$ACTION $TLS_CERT_FILENAME $TLS_KEY_FILENAME $TLS_BUNDLE_FILENAME
