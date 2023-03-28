#!/bin/bash

#
# Run with:
#
# bash /tmp/bigIPCollect.sh username password
#

BANNER="Second Sight - https://github.com/F5Networks/SecondSight\n\n
This tool collects usage tracking data from BIG-IP for offline postprocessing.\n\n
=== Usage:\n\n
$0 [options]\n\n
=== Options:\n\n
-h\t\t\t- This help\n
-i\t\t\t- Interactive mode\n
-u [username]\t\t- BIG-IP username (batch mode)\n
-p [password]\t\t- BIG-IP password (batch mode)\n
-s [http(s)://address]\t- Upload data to Second Sight (optional)\n\n
=== Examples:\n\n
Interactive mode:\n
\t$0 -i\n
\t$0 -i -s https://<SECOND SIGHT GUI ADDRESS>\n\n
Batch mode:\n
\t$0 -u [username] -p [password]\n
\t$0 -u [username] -p [password] -s https://<SECOND SIGHT GUI ADDRESS>\n
"

while getopts 'hiu:p:s:' OPTION
do
	case "$OPTION" in
		h)
			echo -e $BANNER
			exit
		;;
		i)
			read -p "Username: " BIGIP_USERNAME
			read -sp "Password: " BIGIP_PASSWORD
			echo
		;;
		u)
			BIGIP_USERNAME=$OPTARG
		;;
		p)
			BIGIP_PASSWORD=$OPTARG
		;;
                s)
                        UPLOAD_SS=$OPTARG
                ;;
	esac
done

if [ "$1" = "" ] || [ "$BIGIP_USERNAME" = "" ] || [ "$BIGIP_PASSWORD" = "" ]
then
	echo -e $BANNER
	exit
fi

AUTH_CHECK=`curl -ks -X POST 'https://127.0.0.1/mgmt/shared/authn/login' -H 'Content-Type: text/plain' -d '{"username": "'$BIGIP_USERNAME'","password": "'$BIGIP_PASSWORD'"}' | jq '.username' -r`

if [ "$AUTH_CHECK" == "null" ]
then
	echo "Wrong credentials: authentication failed"
	exit
fi

RC="restcurl -u $BIGIP_USERNAME:$BIGIP_PASSWORD"

echo "-> Collecting global settings"
BIGIP_GLOBAL=`$RC /mgmt/tm/sys/global-settings`

echo "-> Collecting management details"
BIGIP_MGMT=`$RC /mgmt/tm/sys/management-ip`

echo "-> Collecting license info"
BIGIP_LICENSE=`$RC /mgmt/tm/sys/license`

echo "-> Collecting software details"
BIGIP_SOFTWARE=`$RC /mgmt/tm/sys/software/volume`

echo "-> Collecting hardware details"
BIGIP_HARDWARE=`$RC /mgmt/tm/sys/hardware`

echo "-> Collecting provisioned modules"
BIGIP_MODULES=`$RC /mgmt/tm/sys/provision`

echo "-> Collecting APM usage"
BIGIP_APM=`$RC /mgmt/tm/apm/license`

# JSON Header
REPORT_KIND="Full"
REPORT_TYPE="Second Sight"
REPORT_VERSION="4.1"
REPORT_DATAPLANE="BIG-IP"
REPORT_TIMESTAMP=`date +"%Y-%m-%d %H:%M:%S.%6N"`

JSON_STRING=$( jq -n \
                  --arg report_kind "$REPORT_KIND" \
                  --arg report_type "$REPORT_TYPE" \
                  --arg report_version "$REPORT_VERSION" \
                  --arg report_dataplane "$REPORT_DATAPLANE" \
                  --arg report_timestamp "$REPORT_TIMESTAMP" \
                  --argjson global "$BIGIP_GLOBAL" \
                  --argjson mgmt "$BIGIP_MGMT" \
                  --argjson license "$BIGIP_LICENSE" \
                  --argjson sw "$BIGIP_SOFTWARE" \
                  --argjson hw "$BIGIP_HARDWARE" \
                  --argjson modules "$BIGIP_MODULES" \
                  --argjson apm "$BIGIP_APM" \
                  '{report: {
			kind: $report_kind,
			type: $report_type,
			version: $report_version,
			dataplane: $report_dataplane,
			timestamp: $report_timestamp
		},
		global: $global,
		mgmt: $mgmt,
		license: $license,
		software: $sw,
		hardware: $hw,
		modules: $modules,
		apm: $apm}
		' )

echo "-> Data collection completed, building JSON payload"

JSONFILEBASENAME=`date +"%Y%m%d-%H%M"`-bigIPCollect.json
JSONFILE=/tmp/$JSONFILEBASENAME
echo $JSON_STRING > $JSONFILE

if [ "$UPLOAD_SS" = "" ]
then
        echo "-> All done, copy $JSONFILE to your local host using scp"
else
        echo "-> Uploading $JSONFILE to Second Sight at $UPLOAD_SS"
        curl -X POST -sk $UPLOAD_SS/api/v1/archive -F "file=@$JSONFILE" -F "description=$JSONFILEBASENAME" -w '\n'
        echo "-> Upload complete"
fi
