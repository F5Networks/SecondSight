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

VERSION="FCP Usage Script - 20241003"
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
-t [seconds]\t\t- BIG-IQ timeout (optional, 90 seconds by default)\n\n
=== Examples:\n\n
Interactive mode:\t\t$0 -i\n
Interactive mode + upload:\t$0 -i -s https://<SECOND_SIGHT_FQDN_OR_IP>\n
Batch mode:\t\t\t$0 -u [username] -p [password] -c [customer_name]\n
Batch mode:\t\t\t$0 -u [username] -p [password] -c [customer_name] -s https://<SECOND_SIGHT_FQDN_OR_IP>\n
"

COLOUR_RED='\033[0;31m'
COLOUR_NONE='\033[0m'
BIGIQ_TIMEOUT=90

while getopts 'hviu:p:s:c:t:' OPTION
do
	case "$OPTION" in
		h)
			echo -e $BANNER
			exit
		;;
		t)
			BIGIQ_TIMEOUT=$OPTARG
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

OUTPUTROOT=/tmp
OUTPUTDIR=`mktemp -d`

EXTRA_INFO_JSON=$OUTPUTDIR/0.bigIQCollect.json

#
# Debug output
#
DEBUGFILE=$OUTPUTDIR/bigIQCollect.out
exec &> >(tee -a $DEBUGFILE)

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

echo "-> Reading device telemetry"
ALL_TELEMETRY="
bigip-cpu|cpu-usage|avg-value-per-event|-1H|5|MINUTES
bigip-cpu|cpu-usage|avg-value-per-event|-1W|3|HOURS
bigip-cpu|cpu-usage|avg-value-per-event|-30D|12|HOURS
bigip-memory|free-ram|avg-value-per-event|-1H|5|MINUTES
bigip-memory|free-ram|avg-value-per-event|-1W|3|HOURS
bigip-memory|free-ram|avg-value-per-event|-30D|12|HOURS
bigip-disk-usage|disk-available-size|avg-value-per-event|-1H|5|MINUTES
bigip-disk-usage|disk-available-size|avg-value-per-event|-1W|3|HOURS
bigip-disk-usage|disk-available-size|avg-value-per-event|-30D|12|HOURS
bigip-traffic-summary|server-connections|avg-value-per-sec|-1H|5|MINUTES
bigip-traffic-summary|server-connections|avg-value-per-sec|-1W|3|HOURS
bigip-traffic-summary|server-connections|avg-value-per-sec|-30D|12|HOURS
bigip-traffic-summary|client-bytes-in|avg-value-per-sec|-1H|5|MINUTES
bigip-traffic-summary|client-bytes-in|avg-value-per-sec|-1W|3|HOURS
bigip-traffic-summary|client-bytes-in|avg-value-per-sec|-30D|12|HOURS
bigip-traffic-summary|client-bytes-out|avg-value-per-sec|-1H|5|MINUTES
bigip-traffic-summary|client-bytes-out|avg-value-per-sec|-1W|3|HOURS
bigip-traffic-summary|client-bytes-out|avg-value-per-sec|-30D|12|HOURS
bigip-traffic-summary|server-bytes-in|avg-value-per-sec|-1H|5|MINUTES
bigip-traffic-summary|server-bytes-in|avg-value-per-sec|-1W|3|HOURS
bigip-traffic-summary|server-bytes-in|avg-value-per-sec|-30D|12|HOURS
bigip-traffic-summary|server-bytes-out|avg-value-per-sec|-1H|5|MINUTES
bigip-traffic-summary|server-bytes-out|avg-value-per-sec|-1W|3|HOURS
bigip-traffic-summary|server-bytes-out|avg-value-per-sec|-30D|12|HOURS
"

ALL_HOSTNAMES=""
AUTH_TOKEN=`getAuthToken $REFRESH_TOKEN`

for T in $ALL_TELEMETRY
do
	T_MODULE=`echo $T | awk -F\| '{print $1}'`
	T_METRICSET=`echo $T | awk -F\| '{print $2}'`
	T_METRIC=`echo $T | awk -F\| '{print $3}'`
	T_TIMERANGE=`echo $T | awk -F\| '{print $4}'`
	T_GRAN_DURATION=`echo $T | awk -F\| '{print $5}'`
	T_GRAN_UNIT=`echo $T | awk -F\| '{print $6}'`

	#echo "- $T_MODULE / $T_METRICSET / $T_METRIC / $T_TIMERANGE / $T_GRAN_DURATION / $T_GRAN_UNIT"

	TELEMETRY_JSON='{
    "kind": "ap:query:stats:byEntities",
    "module": "'$T_MODULE'",
    "timeRange": {
            "from": "'$T_TIMERANGE'",
            "to": "now"
    },
    "dimension": "hostname",
    "aggregations": {
            "'$T_METRICSET'$'$T_METRIC'": {
                    "metricSet": "'$T_METRICSET'",
                    "metric": "'$T_METRIC'"
            }
    },
    "timeGranularity": {
      "duration": '$T_GRAN_DURATION',
      "unit": "'$T_GRAN_UNIT'"
    },
    "limit": 1000
}'

	TELEMETRY_OUTPUT=`curl -ksX POST https://127.0.0.1/mgmt/ap/query/v1/tenants/default/products/device/metric-query -H "X-F5-Auth-Token: $AUTH_TOKEN" -H "Content-Type: application/json" -d "$TELEMETRY_JSON"`
        OUTFILE=$OUTPUTDIR/telemetry-$T_MODULE-$T_METRICSET-$T_TIMERANGE.json

	echo $TELEMETRY_OUTPUT > $OUTFILE

	if [ "$ALL_HOSTNAMES" = "" ]
	then
		ALL_HOSTNAMES=`echo $TELEMETRY_OUTPUT |jq -r '.result.result[].hostname' 2>/dev/null`
	fi
done

## Datapoints telemetry

AUTH_TOKEN=`getAuthToken $REFRESH_TOKEN`

for TDP_HOSTNAME in $ALL_HOSTNAMES
do

echo "-> Reading device telemetry datapoints for [$TDP_HOSTNAME]"

for TDP in $ALL_TELEMETRY
do
	TDP_MODULE=`echo $TDP | awk -F\| '{print $1}'`
	TDP_METRICSET=`echo $TDP | awk -F\| '{print $2}'`
	TDP_METRIC=`echo $TDP | awk -F\| '{print $3}'`
	TDP_TIMERANGE=`echo $TDP | awk -F\| '{print $4}'`
	TDP_GRAN_DURATION=`echo $TDP | awk -F\| '{print $5}'`
	TDP_GRAN_UNIT=`echo $TDP | awk -F\| '{print $6}'`

	#echo "- $TDP_HOSTNAME -> $TDP_MODULE / $TDP_METRICSET / $TDP_METRIC / $TDP_TIMERANGE / $TDP_GRAN_DURATION / $TDP_GRAN_UNIT"

	TELEMETRY_DP_JSON='{
    "kind": "ap:query:stats:byTime",
    "module": "'$TDP_MODULE'",
    "timeRange": {
            "from": "'$TDP_TIMERANGE'",
            "to": "now"
    },
    "dimension": "hostname",
    "dimensionFilter": {
            "type": "eq",
            "dimension": "hostname",
            "value": "'$TDP_HOSTNAME'"
    },
    "aggregations": {
            "'$TDP_METRICSET'$'$TDP_METRIC'": {
                    "metricSet": "'$TDP_METRICSET'",
                    "metric": "'$TDP_METRIC'"
            }
    },
    "timeGranularity": {
      "duration": '$TDP_GRAN_DURATION',
      "unit": "'$TDP_GRAN_UNIT'"
    },
    "limit": 1000
}'

	TELEMETRY_DP_OUTPUT=`curl -ksX POST https://127.0.0.1/mgmt/ap/query/v1/tenants/default/products/device/metric-query -H "X-F5-Auth-Token: $AUTH_TOKEN" -H "Content-Type: application/json" -d "$TELEMETRY_DP_JSON"`
        OUTFILE=$OUTPUTDIR/telemetry-datapoints-$TDP_HOSTNAME-$TDP_MODULE-$TDP_METRICSET-$TDP_TIMERANGE.json

	echo $TELEMETRY_DP_OUTPUT > $OUTFILE
done

done

### /Datapoints telemetry

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
CURRENT_TIME=`date +"%Y%m%d-%H%M"`

echo "-> Adding summary"
echo "... Timestamp [$CURRENT_TIME]"
echo "... Customer Name [$CUSTOMER_NAME]"
echo "... Total devices [$DEVICE_COUNTER]"

cat - << __EOT__ > $EXTRA_INFO_JSON
{
  "version": "$VERSION",
  "customerName": "$CUSTOMER_NAME",
  "timestamp": "$CURRENT_TIME",
  "totalDevices": $DEVICE_COUNTER
}
__EOT__

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
