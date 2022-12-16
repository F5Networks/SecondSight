#!/bin/bash

### Optional listen address and port
#export F5TT_ADDRESS=0.0.0.0
#export F5TT_PORT=5000

### Optional HTTP(S) proxy
#export HTTP_PROXY="http(s)://username:password@proxy_ip:port"
#export HTTPS_PROXY="http(s)://username:password@proxy_ip:port"

### Optional NIST API Key for full CVE tracking (https://nvd.nist.gov/developers/request-an-api-key)
#export NIST_API_KEY=xxxxxxxx

### Section to use when polling NGINX Instance Manager 2.x

#export DATAPLANE_TYPE=NGINX_MANAGEMENT_SYSTEM
#export DATAPLANE_FQDN="https://ubuntu.ff.lan"
#export DATAPLANE_USERNAME="theusername"
#export DATAPLANE_PASSWORD="thepassword"
# NMS_AUTH_TYPE can be: basic, digest, jwt. "basic" is the default
#export NMS_AUTH_TYPE="basic"
#export NMS_AUTH_TOKEN="JWT_TOKEN_HERE"
#export NMS_CH_HOST="127.0.0.1"
#export NMS_CH_PORT="9000"
#export NMS_CH_USER="default"
#export NMS_CH_PASS=""
#export NMS_CH_SAMPLE_INTERVAL=1800

### Section to use when polling BIG-IQ

#export DATAPLANE_TYPE=BIG_IQ
#export DATAPLANE_FQDN="https://bigiq.ff.lan"
#export DATAPLANE_USERNAME="username"
#export DATAPLANE_PASSWORD="thepassword"

### Section to use when using push in pushgateway mode (basic auth username/password are optional)

#export STATS_PUSH_ENABLE="true"
#export STATS_PUSH_MODE=PUSHGATEWAY
#export STATS_PUSH_URL="http://pushgateway.nginx.ff.lan"
# STATS_PUSH_INTERVAL in seconds
#export STATS_PUSH_INTERVAL=10
#export STATS_PUSH_USERNAME="authusername"
#export STATS_PUSH_PASSWORD="authpassword"

### Section to use when using push in custom mode (basic auth username/password are optional)

#export STATS_PUSH_ENABLE="false"
#export STATS_PUSH_MODE=CUSTOM
#export STATS_PUSH_URL="http://192.168.1.18/callHome"
# STATS_PUSH_INTERVAL in seconds
#export STATS_PUSH_INTERVAL=10
#export STATS_PUSH_USERNAME="authusername"
#export STATS_PUSH_PASSWORD="authpassword"

### Section to use when using e-mail based push
#export EMAIL_ENABLED="false"
#export EMAIL_SERVER="smtp.mydomain.tld"
# Port 25 for SMTP, 465 for SMTP over TLS
#export EMAIL_SERVER_PORT=25
# EMAIL_SERVER_TYPE can be: starttls, ssl, plaintext
#export EMAIL_SERVER_TYPE="starttls"
#export EMAIL_SENDER="sender@domain.tld"
#export EMAIL_RECIPIENT="recipient@domain.tld"
# EMAIL_INTERVAL in minutes
#export EMAIL_INTERVAL=15
# Optional for SMTP authentication
#export EMAIL_AUTH_USER="username@domain"
#export EMAIL_AUTH_PASS="thepassword"

python3 app.py
