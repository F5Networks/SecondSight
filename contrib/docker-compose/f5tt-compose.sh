#!/bin/bash

#
# Usage
#
usage() {
BANNER="Second Sight - https://github.com/F5Networks/SecondSight/\n\n
This script is used to deploy/remove Second Sight with docker-compose\n\n
=== Usage:\n\n
$0 [options]\n\n
=== Options:\n\n
-h\t\t\t- This help\n\n
-c [start|stop]\t- Deployment command\n
-t [bigiq]\t\t- Deployment type\n\n
-s [url]\t\t- BIG-IQ URL\n
-u [username]\t\t- BIG-IQ username\n
-p [password]\t\t- BIG-IQ password\n\n
-k [NIST API key]\t- NIST CVE REST API Key (https://nvd.nist.gov/developers/request-an-api-key)\n\n
=== Examples:\n\n
Deploy Second Sight for BIG-IQ:\t\t\t$0 -c start -t bigiq -s https://<BIGIQ_ADDRESS> -u <username> -p <password>\n
Remove Second Sight for BIG-IQ:\t\t\t$0 -c stop -t bigiq\n
"

echo -e $BANNER 2>&1
exit 1
}

#
# Second Sight deployment
# parameters: [bigiq] [controlplane URL] [username] [password] [NIST CVD key]
#
f5tt_start() {
if [ "$#" -lt 4 ]
then
	exit
fi

MODE=$1

# Docker compose variables
USERNAME=`whoami`
export USERID=`id -u $USERNAME`
export USERGROUP=`id -g $USERNAME`

export DATAPLANE_FQDN=$2
export DATAPLANE_USERNAME=$3
export DATAPLANE_PASSWORD=$4
export NIST_API_KEY=$5

echo "-> Deploying Second Sight for $MODE at $DATAPLANE_FQDN" 
echo "Creating persistent storage directories under /opt/f5tt ..."
echo "Enter sudo password if prompted"

sudo bash -c "mkdir -p /opt/f5tt;chown $USERID:$USERGROUP /opt/f5tt"

if [ "$MODE" = "bigiq" ]
then
	mkdir -p /opt/f5tt/{prometheus,grafana/data,grafana/log,grafana/plugins}
fi

docker-compose -f $DOCKER_COMPOSE_YAML-$MODE.yaml pull
COMPOSE_HTTP_TIMEOUT=240 docker-compose -p $PROJECT_NAME-$MODE -f $DOCKER_COMPOSE_YAML-$MODE.yaml up -d --remove-orphans
}

#
# Second Sight removal
# parameters: [bigiq]
#
f5tt_stop() {
if [ "$#" != 1 ]
then
	echo "Extra commandline parameters, aborting"
	exit
fi

MODE=$1

# Docker compose variables
USERNAME=`whoami`
export USERID=`id -u $USERNAME`
export USERGROUP=`id -g $USERNAME`
export DATAPLANE_FQDN=""
export DATAPLANE_USERNAME=""
export DATAPLANE_PASSWORD=""
export NIST_API_KEY=""

echo "-> Undeploying Second Sight for $MODE"

COMPOSE_HTTP_TIMEOUT=240 docker-compose -p $PROJECT_NAME-$MODE -f $DOCKER_COMPOSE_YAML-$MODE.yaml down
}

#
# Main
#

DOCKER_COMPOSE_YAML=f5tt-compose
PROJECT_NAME=f5tt
NIST_API_KEY=""

while getopts 'hc:t:s:u:p:k:' OPTION
do
        case "$OPTION" in
                h)
			usage
                ;;
                c)
                        ACTION=$OPTARG
                ;;
                t)
                        MODE=$OPTARG
                ;;
		s)
			DATAPLANE_URL=$OPTARG
		;;
		u)
			DATAPLANE_USERNAME=$OPTARG
		;;
		p)
			DATAPLANE_PASSWORD=$OPTARG
		;;
		k)
			NIST_API_KEY=$OPTARG
		;;
        esac
done

if [ -z "${ACTION}" ] || [ -z "${MODE}" ] || [[ ! "${ACTION}" == +(start|stop) ]] || [[ ! "${MODE}" == +(bigiq) ]] ||
	([ "${ACTION}" = "start" ] && ([ -z "${DATAPLANE_URL}" ] || [ -z "${DATAPLANE_USERNAME}" ] || [ -z "${DATAPLANE_PASSWORD}" ]))
then
	usage
fi

f5tt_$ACTION $MODE $DATAPLANE_URL $DATAPLANE_USERNAME $DATAPLANE_PASSWORD $NIST_API_KEY
