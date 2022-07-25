#!/bin/bash

BANNER="Second Sight - https://github.com/F5Networks/SecondSight\n\n
This tool manages Second Sight running on docker on a BIG-IQ Centralized Manager VM.\n\n
=== Usage:\n\n
$0 [options]\n\n
=== Options:\n\n
-h\t\t- This help\n
-l\t\t- Local mode - to be used if BIG-IQ can't connect to the Internet\n
-s\t\t- Start Second Sight\n
-k\t\t- Stop (kill) Second Sight\n
-c\t\t- Check Second Sight run status\n
-u [username]\t- BIG-IQ username (batch mode)\n
-p [password]\t- BIG-IQ password (batch mode)\n
-f\t\t- Fetch JSON report\n
-a [mode]\t- All-in-one mode: start Second Sight, collect JSON report and stop Second Sight\n
\t\t\t[mode] = \"online\" if BIG-IQ has Internet connectivity, \"offline\" otherwise\n\n
=== Examples:\n\n
Start:\n
\tInteractive mode (BIG-IQ with Internet connectivity):\t\t$0 -s\n
\tInteractive mode (BIG-IQ with no Internet connectivity):\t$0 -s -l\n
\tBatch mode (BIG-IQ with Internet connectivity):\t\t\t$0 -s -u [username] -p [password]\n
\tBatch mode (BIG-IQ with no Internet connectivity):\t\t$0 -s -l -u [username] -p [password]\n
Stop:\n
\tBIG-IQ with Internet connectivity:\t\t\t\t$0 -k\n
\tBIG-IQ with no Internet connectivity:\t\t\t\t$0 -k -l\n
Fetch JSON:\n
\t$0 -f\n
All-in-one:\n
\tBIG-IQ with Internet connectivity:\t\t\t\t$0 -a online\n
\tBIG-IQ with no Internet connectivity:\t\t\t\t$0 -a offline\n
"

while getopts 'lskhcfa:u:p:' OPTION
do
        case "$OPTION" in
		l)
			echo "-> Running in local mode"
			LOCAL_MODE="yes"
		;;
                h)
                        echo -e $BANNER
                        exit
                ;;
                u)
                        BIGIQ_USERNAME=$OPTARG
                ;;
                p)
                        BIGIQ_PASSWORD=$OPTARG
                ;;
		s)
			MODE="start"
		;;
		k)
			MODE="stop"
		;;
		c)
			CHECK=`docker ps -q -f name=f5tt`
			if [ "$CHECK" = "" ]
			then
				echo "-> Second Sight not running"
				exit 0
			else
				echo "-> Second Sight running"
				exit 1
			fi
		;;
		f)
			$0 -c >/dev/null
			F5TT_STATUS=$?

			if [ $F5TT_STATUS = 0 ]
			then
				echo "-> Second Sight not running"
			else
				echo "-> Collecting report..."
				JSONFILE=/tmp/`date +"%Y%m%d-%H%M"`-instances.json
				curl -s http://127.0.0.1:5000/instances > $JSONFILE

				echo "-> JSON report generated, copy $JSONFILE to your local host using scp"
			fi

			exit
		;;
		a)
			LOCAL_MODE=$OPTARG

			case "$LOCAL_MODE" in
				'online')
					$0 -s
					sleep 5
					$0 -f
					$0 -k
				;;
				'offline')
					$0 -s -l
					if [ $? == 255 ]
					then
						exit
					fi
					sleep 5
					$0 -f
					$0 -k
				;;
				*)
					echo "Invalid parameter $LOCAL_MODE"
					exit
				;;
			esac

			exit
		;;
        esac
done

if [ "$MODE" = "" ]
then
        echo -e $BANNER
        exit
fi

DOCKER_IMAGE=fiorucci/f5-telemetry-tracker:latest
DOCKER_IP=`ip add show docker0 | grep inet\  | awk '{print $2}' | awk -F\/ '{print $1}'`
LOCAL_IMAGE=/shared/images/tmp/F5-Telemetry-Tracker.tar

if [ "$LOCAL_MODE" = "yes" ]
then
	if [ ! -f "$LOCAL_IMAGE" ] && [ ! -f "$LOCAL_IMAGE.gz" ]
	then
		echo -e "Fatal Error:\n\nRunning in local mode: $LOCAL_IMAGE not found\nCheck the documentation at https://github.com/F5Networks/SecondSight/tree/main/contrib/bigiq-docker\n"
		exit -1
	fi
fi

if [ "$MODE" = "start" ]
then
	if [ "$BIGIQ_USERNAME" = "" ] || [ "$BIGIQ_PASSWORD" = "" ]
	then
		read -p "Username: " BIGIQ_USERNAME
		read -sp "Password: " BIGIQ_PASSWORD
		echo
	fi
fi

case $MODE in
	'start')
		mv /etc/systemd/system/docker.service.d/http-proxy.conf /etc/systemd/system/docker.service.d/http-proxy.conf.disabled 2>/dev/null
		systemctl stop docker 2>/dev/null
		systemctl daemon-reload 2>/dev/null
		systemctl start docker 2>/dev/null

		if [ "$LOCAL_MODE" = "yes" ]
		then
			echo "-> Decompressing Second Sight docker image"
			gzip -d $LOCAL_IMAGE.gz >/dev/null 2>/dev/null
			echo "-> Loading Second Sight docker image"
			docker load < $LOCAL_IMAGE
		fi

		echo "-> Starting Second Sight, please stand by..."
		docker run -d --name f5tt \
		-p 5000:5000 \
		-e DATAPLANE_TYPE=BIG_IQ \
		-e DATAPLANE_FQDN="https://$DOCKER_IP" \
		-e DATAPLANE_USERNAME=$BIGIQ_USERNAME \
		-e DATAPLANE_PASSWORD=$BIGIQ_PASSWORD \
		fiorucci/f5-telemetry-tracker:latest 2>/dev/null >/dev/null

		MGMT_IP=`ip add show mgmt | grep inet\  | awk '{print $2}' | awk -F\/ '{print $1}'`
		echo "-> Second Sight started on http://$MGMT_IP:5000"
	;;
	'stop')
		docker stop f5tt 2>/dev/null >/dev/null
		docker rm f5tt 2>/dev/null >/dev/null

		mv /etc/systemd/system/docker.service.d/http-proxy.conf.disabled /etc/systemd/system/docker.service.d/http-proxy.conf 2>/dev/null
		systemctl stop docker 2>/dev/null
		systemctl daemon-reload 2>/dev/null
		systemctl start docker 2>/dev/null

		echo "-> Second Sight stopped"
	;;
esac
