#!/bin/bash

TGZFILE=$1
python3 f5ttfs.py $TGZFILE &
F5TTFS_PID=$!

export DATAPLANE_TYPE=BIG_IQ
export DATAPLANE_FQDN="http://127.0.0.1:5001"
export DATAPLANE_USERNAME="notused"
export DATAPLANE_PASSWORD="notused"

### Optional NIST API Key for CVE tracking (https://nvd.nist.gov/developers/request-an-api-key)
#export NIST_API_KEY=xxxxxxx

python3 ../../f5tt/app.py

kill $F5TTFS_PID
