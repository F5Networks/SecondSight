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
-h\t\t- This help\n
-i\t\t- Interactive mode\n
-u [username]\t- BIG-IP username (batch mode)\n
-p [password]\t- BIG-IP password (batch mode)\n\n
=== Examples:\n\n
Interactive mode:\t$0 -i\n
Batch mode:\t\t$0 -u [username] -p [password]\n
"

while getopts 'hiu:p:' OPTION
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

OUTPUTROOT=/tmp
OUTPUTDIR=`mktemp -d`

echo "-> Collecting License info"
restcurl -u $BIGIP_USERNAME:$BIGIP_PASSWORD /mgmt/tm/sys/license > $OUTPUTDIR/1.bigIPLicense.json

echo "-> Collecting Software release info"
restcurl -u $BIGIP_USERNAME:$BIGIP_PASSWORD /mgmt/tm/sys/software/volume > $OUTPUTDIR/2.bigIPsoftware.json

echo "-> Collecting Provisioned modules info"
restcurl -u $BIGIP_USERNAME:$BIGIP_PASSWORD /mgmt/tm/sys/provision > $OUTPUTDIR/3.bigIPmodules.json

echo "-> Collecting APM usage"
restcurl -u $BIGIP_USERNAME:$BIGIP_PASSWORD /mgmt/tm/apm/license > $OUTPUTDIR/4.bigIPAPMUsage.json

echo "-> Collecting Hardware info"
restcurl -u $BIGIP_USERNAME:$BIGIP_PASSWORD /mgmt/tm/sys/hardware > $OUTPUTDIR/5.bigIPhardware.json


echo "-> Data collection completed, building tarfile"
TARFILE=$OUTPUTROOT/`date +"%Y%m%d-%H%M"`-bigIPCollect.tgz
tar zcmf $TARFILE $OUTPUTDIR 2>/dev/null
rm -rf $OUTPUTDIR

echo "-> All done, copy $TARFILE to your local host using scp"
