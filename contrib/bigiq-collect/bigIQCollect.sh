#!/bin/bash

#
# Run with:
#
# bash /tmp/bigIQCollect.sh username password
#

#
# https://clouddocs.f5.com/products/big-iq/mgmt-api/v0.0/ApiReferences/bigiq_public_api_ref/r_auth_login.html
# $1 is the BIG-IQ admin username
# $2 is the BIG-IQ admin password
#
getRefreshToken() {
  echo `curl -ksX POST 'https://127.0.0.1/mgmt/shared/authn/login' -H 'Content-Type: text/plain' -d '{"username": "'$1'","password": "'$2'"}' | jq '.refreshToken.token' -r`
}

#
# https://clouddocs.f5.com/products/big-iq/mgmt-api/v0.0/ApiReferences/bigiq_public_api_ref/r_auth_exchange.html#post-mgmt-shared-authn-exchange
# $1 is the refresh token to exchange for an access token
#
getAuthToken() {
  echo `curl -ksX POST 'https://127.0.0.1/mgmt/shared/authn/exchange' -H 'Content-Type: text/plain' -d '{"refreshToken": {"token": "'$1'"}}' | jq '.token.token' -r`
}

#
# Build tarfile with optional upload to Second Sight
#
finalizeTarfile() {
  ## Building tarfile
  echo "-> Data collection completed, building tarfile"
  CUSTOMER_NAME="${CUSTOMER_NAME//[^[:alnum:]]/_}"
  TARFILEBASENAME=$CUSTOMER_NAME-$CURRENT_TIME-bigIQCollect.tgz
  TARFILE=$OUTPUTROOT/$TARFILEBASENAME
  tar zcmf $TARFILE $OUTPUTDIR 2>/dev/null
  rm -rf $OUTPUTDIR

  if [ "$UPLOAD_SS" = "" ]
  then
    echo "-> All done, copy $TARFILE to your local host using scp"
  else
    echo "-> Uploading $TARFILE to Second Sight at $UPLOAD_SS"
    curl -X POST -sk $UPLOAD_SS/api/v1/archive -F "file=@$TARFILE" -F "description=$TARFILEBASENAME"
    echo "-> Upload complete"
  fi
}

VERSION="FCP Usage Script - 20250212"
BANNER="$VERSION - https://github.com/F5Networks/SecondSight\n\n
This tool collects usage tracking data from BIG-IQ for offline postprocessing.\n\n
=== Usage:\n\n
$0 [options]\n\n
=== Options:\n\n
-h\t\t\t- This help\n
-v\t\t\t- Show version\n
-i\t\t\t- Interactive mode\n
-u [username]\t\t- BIG-IQ username (batch mode)\n
-p [password]\t\t- BIG-IQ password (batch mode)\n
-c [customer_name]\t- Customer name (batch mode)\n
-s [http(s)://address]\t- Upload data to Second Sight (optional)\n
-t [seconds]\t\t- BIG-IQ timeout (optional, 30 seconds by default)\n
-d\t\t\t\t- Collect data for troubleshooting purposes\n\n
=== Examples:\n\n
Interactive mode:\t\t$0 -i\n
Interactive mode + upload:\t$0 -i -s https://<SECOND_SIGHT_FQDN_OR_IP>\n
Batch mode:\t\t\t$0 -u [username] -p [password] -c [customer_name]\n
Batch mode + upload:\t\t$0 -u [username] -p [password] -c [customer_name] -s https://<SECOND_SIGHT_FQDN_OR_IP>\n\n
Collect debug data:\t\t$0 -i -d\n
"

COLOUR_RED='\033[0;31m'
COLOUR_NONE='\033[0m'
BIGIQ_TIMEOUT=30

while getopts 'hviu:p:s:c:t:d' OPTION
do
  case "$OPTION" in
    h)
      echo -e $BANNER
      exit
    ;;
    t)
      BIGIQ_TIMEOUT=$OPTARG
    ;;
    d)
      DEBUG_MODE=true
    ;;
    i)
      read -p "Username: " BIGIQ_USERNAME
      read -sp "Password: " BIGIQ_PASSWORD
      echo
      read -p "Customer name: " CUSTOMER_NAME
    ;;
    u)
      BIGIQ_USERNAME=$OPTARG
    ;;
    p)
      BIGIQ_PASSWORD=$OPTARG
    ;;
    s)
      UPLOAD_SS=$OPTARG
    ;;
    c)
      CUSTOMER_NAME=$OPTARG
    ;;
    v)
      echo $VERSION
      exit
    ;;
  esac
done

if [ "$1" = "" ] || [ "$BIGIQ_USERNAME" = "" ] || [ "$BIGIQ_PASSWORD" = "" ] || [ "$CUSTOMER_NAME" = "" ]
then
	echo -e $BANNER
	exit
fi

echo $VERSION

CURRENT_TIME=`date +"%Y%m%d-%H%M"`
OUTPUTROOT=/tmp
OUTPUTDIR=`mktemp -d`

EXTRA_INFO_JSON=$OUTPUTDIR/0.bigIQCollect.json
DEBUG_INFO_JSON=$OUTPUTDIR/99.bigIQCollect.json

#
# Debug output
#
DEBUGFILE=$OUTPUTDIR/bigIQCollect.out
exec &> >(tee -a $DEBUGFILE)

### Collect troubleshooting details if '-d' option is used
if [ $DEBUG_MODE ]
then
  echo "-> Collecting debug information"
  echo "... tmsh show"
  TMSH_SHOW=`tmsh show | jq -Rsc 'split("\n")'`
  echo "... df"
  BASH_DF=`df -k | jq -Rsc 'split("\n")'`
  echo "... free"
  BASH_FREE=`free | jq -Rsc 'split("\n")'`
  echo "... uptime"
  BASH_UPTIME=`uptime | jq -Rsc 'split("\n")'`
  echo "... ps auxw"
  BASH_PS=`ps auxw | jq -Rsc 'split("\n")'`
  echo "... pstree"
  BASH_PSTREE=`pstree | jq -Rsc 'split("\n")'`
  echo "... bigstart status"
  BASH_BIGSTART_STATUS=`bigstart status | jq -Rsc 'split("\n")'`

  cat - << __EOT__ > $DEBUG_INFO_JSON
{
  "tmsh_show": $TMSH_SHOW,
  "df": $BASH_DF,
  "free": $BASH_FREE,
  "uptime": $BASH_UPTIME,
  "ps": $BASH_PS,
  "pstree": $BASH_PSTREE,
  "bigstart": {
    "status": $BASH_BIGSTART_STATUS
  }
}
__EOT__

  finalizeTarfile
  exit
fi

# Disable HTTP(S) proxies
export https_proxy=
export http_proxy=

touch $DEBUG_INFO_JSON

REFRESH_TOKEN=`getRefreshToken $BIGIQ_USERNAME $BIGIQ_PASSWORD`

if [ "$REFRESH_TOKEN" == "null" ]
then
	echo "Wrong credentials: authentication failed"
	exit
fi

if [ "$REFRESH_TOKEN" == "" ]
then
	echo "BIG-IQ REST API connection refused"
	exit
fi

echo "-> Authentication successful"

echo "-> Reading device list"
AUTH_TOKEN=`getAuthToken $REFRESH_TOKEN`
curl -ksX GET "https://127.0.0.1/mgmt/shared/resolver/device-groups/cm-bigip-allBigIpDevices/devices" -H "X-F5-Auth-Token: $AUTH_TOKEN" > $OUTPUTDIR/1.bigIQCollect.json

echo "-> Reading system provisioning"
AUTH_TOKEN=`getAuthToken $REFRESH_TOKEN`
curl -m 30 -ksX GET "https://127.0.0.1/mgmt/cm/shared/current-config/sys/provision" -H "X-F5-Auth-Token: $AUTH_TOKEN" > $OUTPUTDIR/2.bigIQCollect.json
if [ $? == 28 ]
then
  printf "${COLOUR_RED}Endpoint /mgmt/cm/shared/current-config/sys/provision timed out${COLOUR_NONE}\n"
  echo '{"exitcode": 28}' > $OUTPUTDIR/2.bigIQCollect.json
fi

# Remove all existing inventories
echo "-> Removing old inventories"
INVENTORY_TASK_IDS=`curl -ksX GET "https://127.0.0.1/mgmt/cm/device/tasks/device-inventory" -H "X-F5-Auth-Token: $AUTH_TOKEN" | jq -r '.items[].id'`
for ID in $INVENTORY_TASK_IDS
do
  curl -ksX DELETE "https://127.0.0.1/mgmt/cm/device/tasks/device-inventory/$ID" -o /dev/null -H "X-F5-Auth-Token: $AUTH_TOKEN"
done

echo "-> Reading device inventory details"
AUTH_TOKEN=`getAuthToken $REFRESH_TOKEN`
INVENTORIES=`curl -ksX GET "https://127.0.0.1/mgmt/cm/device/tasks/device-inventory" -H "X-F5-Auth-Token: $AUTH_TOKEN"`
INVENTORIES_LEN=`echo $INVENTORIES | jq '.items|length'`

if [ $INVENTORIES_LEN == 0 ]
then
  echo "... $INVENTORIES_LEN inventories found: refresh requested"
  AUTH_TOKEN=`getAuthToken $REFRESH_TOKEN`
  curl -ksX POST "https://127.0.0.1/mgmt/cm/device/tasks/device-inventory" -H "X-F5-Auth-Token: $AUTH_TOKEN" -H "Content-Type: application/json" -d '{"devicesQueryUri": "https://localhost/mgmt/shared/resolver/device-groups/cm-bigip-allBigIpDevices/devices"}' > /dev/null

  while [ $INVENTORIES_LEN == 0 ]
  do
    echo "... waiting for inventory refresh, sleeping for $BIGIQ_TIMEOUT seconds"
    sleep $BIGIQ_TIMEOUT
    AUTH_TOKEN=`getAuthToken $REFRESH_TOKEN`
    INVENTORIES=`curl -ksX GET "https://127.0.0.1/mgmt/cm/device/tasks/device-inventory" -H "X-F5-Auth-Token: $AUTH_TOKEN"`
    INVENTORIES_LEN=`echo $INVENTORIES | jq '.items|length'`
  done
fi

echo "-> Found $INVENTORIES_LEN inventories"

echo $INVENTORIES > $OUTPUTDIR/3.bigIQCollect.json

echo "-> Inventories summary"
echo $INVENTORIES | jq -r '.items[].status' | sort | uniq -c

INV_ID=`echo $INVENTORIES | jq -r '.items['$(expr $INVENTORIES_LEN - 1)'].resultsReference.link' | head -n1 | awk -F \/ '{print $9}'`

echo "-> Using inventory [$INV_ID]"

if [ ! "$INV_ID" = "" ]
then

AUTH_TOKEN=`getAuthToken $REFRESH_TOKEN`
curl -ksX GET "https://127.0.0.1/mgmt/cm/device/reports/device-inventory/$INV_ID/results" -H "X-F5-Auth-Token: $AUTH_TOKEN" > $OUTPUTDIR/4.bigIQCollect.json

MACHINE_IDS=`cat $OUTPUTDIR/4.bigIQCollect.json | jq -r '.items[].infoState.machineId'`
DEVICE_COUNTER=0

for M in $MACHINE_IDS
do
	echo "-> Reading device info for [$M]"
	AUTH_TOKEN=`getAuthToken $REFRESH_TOKEN`
	curl -ksX GET "https://127.0.0.1/mgmt/cm/system/machineid-resolver/$M" -H "X-F5-Auth-Token: $AUTH_TOKEN" > $OUTPUTDIR/machineid-resolver-$M.json
	DEVICE_COUNTER=$((DEVICE_COUNTER+1))
done

echo "-> Collecting F5OS configuration"
AUTH_TOKEN=`getAuthToken $REFRESH_TOKEN`
curl -ksX GET "https://127.0.0.1/mgmt/cm/f5os/config" -H "X-F5-Auth-Token: $AUTH_TOKEN" > $OUTPUTDIR/5.bigIQCollect.json

fi

### Utility billing collection

AUTH_TOKEN=`getAuthToken $REFRESH_TOKEN`

UTB_ALLLICENSES=`curl -ks -X GET "https://127.0.0.1/mgmt/cm/device/licensing/pool/utility/licenses?$select=regKey,status" -H "X-F5-Auth-Token: $AUTH_TOKEN"`
echo $UTB_ALLLICENSES > $OUTPUTDIR/utilitybilling-licenses.json

UTB_ALLREGKEYS=`echo $UTB_ALLLICENSES | jq -r '.items[]|.regKey'`

FIRST_DAY_PREV_MONTH=`date --date="$(date +'%Y-%m-01') - 1 month" +%Y-%m-%d`
LAST_DAY_PREV_MONTH=`date --date="$(date +'%Y-%m-01') - 1 second" +%Y-%m-%d`

for REGKEY in $UTB_ALLREGKEYS
do
	echo "-> Collecting utility billing for regkey [$REGKEY]"

	# Licensing reports
	REPORT_STATUS_JSON=`curl -ksX POST https://127.0.0.1/mgmt/cm/device/tasks/licensing/reports -H "X-F5-Auth-Token: $AUTH_TOKEN" -H "Content-Type: application/json" \
		-d '{"submissionMethod": "manual", "typeOfReport": "Historical","obfuscateDeviceInfo": false,"reportFileFormat": "JSON","regKey": "'$REGKEY'","reportStartDateTime": "'$FIRST_DAY_PREV_MONTH'T00:00:00Z","reportEndDateTime": "'$LAST_DAY_PREV_MONTH'T23:59:59Z"}'`

	REPORT_STATUS_ID=`echo $REPORT_STATUS_JSON | jq -r '.selfLink' | awk -F\/ '{print $10}'`
	echo $REPORT_STATUS_JSON > $OUTPUTDIR/utilitybilling-createreport-$REGKEY.json

	sleep 4

	REPORT_DOWNLOAD_JSON=`curl -ksX GET https://127.0.0.1/mgmt/cm/device/tasks/licensing/reports/$REPORT_STATUS_ID -H "X-F5-Auth-Token: $AUTH_TOKEN"`
	REPORT_DOWNLOAD_FILE=`echo $REPORT_DOWNLOAD_JSON | jq -r '.reportUri' | awk -F\/ '{print $9}'`
	echo $REPORT_DOWNLOAD_JSON > $OUTPUTDIR/utilitybilling-reportstatus-$REPORT_STATUS_ID.json

	REPORT_JSON=`curl -ksX GET https://127.0.0.1/mgmt/cm/device/licensing/license-reports-download/$REPORT_DOWNLOAD_FILE -H "X-F5-Auth-Token: $AUTH_TOKEN"`
	echo $REPORT_JSON > $OUTPUTDIR/utilitybilling-billingreport-$REPORT_DOWNLOAD_FILE
done

### /Utility billing collection

### Summary

echo "-> Adding summary"
echo "... Timestamp [$CURRENT_TIME]"
echo "... Customer Name [$CUSTOMER_NAME]"
echo "... Total devices [$DEVICE_COUNTER]"

### BIG-IQ information
TMSH_VERSION=`tmsh show sys version | jq -Rsc 'split("\n")'`

cat - << __EOT__ > $EXTRA_INFO_JSON
{
  "version": "$VERSION",
  "customerName": "$CUSTOMER_NAME",
  "timestamp": "$CURRENT_TIME",
  "totalDevices": $DEVICE_COUNTER,
  "bigiq": { "version": $TMSH_VERSION }
}
__EOT__

finalizeTarfile
