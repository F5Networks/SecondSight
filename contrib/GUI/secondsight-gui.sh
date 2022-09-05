#!/bin/bash

#
# Usage
#
usage() {
BANNER="Second Sight GUI - https://github.com/F5Networks/SecondSight/\n\n
This script is used to deploy/undeploy Second Sight GUI using docker-compose\n\n
=== Usage:\n\n
$0 [options]\n\n
=== Options:\n\n
-h\t\t\t- This help\n
-c [start|stop]\t- Deployment command\n
-x\t\t\t- Remove backend persistent data\n\n
=== Examples:\n\n
Deploy Second Sight GUI:\t$0 -c start\n
Remove Second Sight GUI:\t$0 -c stop\n
Remove backend data:\t\t$0 -x\n
"

echo -e $BANNER 2>&1
exit 1
}

#
# Second Sight GUI deployment
#
gui_start() {
echo "-> Deploying Second Sight GUI"
docker-compose -f $DOCKER_COMPOSE_YAML pull
COMPOSE_HTTP_TIMEOUT=240 docker-compose -p $PROJECT_NAME -f $DOCKER_COMPOSE_YAML up -d --remove-orphans
}

#
# Second Sight GUI removal
#
gui_stop() {
echo "-> Undeploying Second Sight GUI"
COMPOSE_HTTP_TIMEOUT=240 docker-compose -p $PROJECT_NAME -f $DOCKER_COMPOSE_YAML down
}

#
# Main
#

DOCKER_COMPOSE_YAML=secondsight-gui.yaml
PROJECT_NAME=secondsight-gui

while getopts 'hc:x' OPTION
do
        case "$OPTION" in
                h)
			usage
                ;;
                c)
                        ACTION=$OPTARG
                ;;
		x)
			echo "-> Removing backend persistent data"
			docker volume rm secondsight-gui_postgres_data
			exit
                ;;
        esac
done

if [ -z "${ACTION}" ] || [[ ! "${ACTION}" == +(start|stop) ]]
then
	usage
fi

gui_$ACTION
