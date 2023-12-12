# Second Sight Data Collector (F5TT)

Second Sight Data Collector is a tool that can be run to collect raw data on hardware and software assets by querying BIG-IQ and NGINX Instance Manager

## Features

Communication to NGINX Instance Manager / BIG-IQ / TMOS is based on REST API, current features are:

- REST API and high level reporting - see [usage page](/USAGE.md)
- JSON Telemetry mode
  - POSTs instance statistics to a user-defined HTTP(S) URL (STATS_PUSH_MODE: CUSTOM)
  - Basic authentication support (BIG-IQ)
  - Basic, Digest and JWT authentication support (NGINX Instance Manager)
  - Configurable push interval (in seconds)
- Grafana visualization mode
  - Pushes instance statistics to pushgateway (STATS_PUSH_MODE: PUSHGATEWAY)
- Automated e-mail reporting
  - Sends an email containing the report JSON file as an attachment named nginx_report.json for NGINX Instance Mana>
  - Support for plaintext SMTP, STARTTLS, SMTP over TLS, SMTP authentication, custom SMTP port
  - Configurable push interval (in days)
- HTTP(S) proxy support
- Realtime CVE tracking
- Resource and applications telemetry (currently supported for BIG-IQ)

## Prerequisites

- Kubernetes/Openshift cluster or Linux host with Docker support
- Private registry to push the Second Sight image if running on Kubernetes/Openshift
- One of:
  - NGINX Instance Manager 2.1.0+
    - Note: NGINX Instance Manager enforces rate limiting on `/api` by default. This needs to be disabled for Second Sight to operate correctly. To do this edit `/etc/nginx/conf.d/nms-http.conf` on NGINX Instance Manager and comment out the following lines in the `location /api` context:
	```
		limit_req zone=nms-ratelimit burst=10 nodelay;
		limit_req_status 429;
	```
	Then reload NGINX configuration using `nginx -s reload`
  - BIG-IQ 8.1.0, 8.1.0.2, 8.2.0
- SMTP server if automated email reporting is used
- NIST NVD REST API Key for full CVE tracking (https://nvd.nist.gov/developers/request-an-api-key)

# How to run

## On Docker Compose

This is the recommended method to run Second Sight data collector on a Linux virtual machine.
Refer to [installation instructions](/contrib/docker-compose)

## As a native python application

Dependencies can be installed using:

```
$ cd f5tt
$ pip install -r requirements.txt
```

`f5tt/f5tt.sh` is a sample script to run Second Sight from bash

## On Kubernetes/Openshift

Second Sight Data Collector image is available on Docker Hub as:

```
fiorucci/f5-telemetry-tracker:latest
```

File `1.f5tt.yaml` references such image by default.

If you need to build and push the docker image to a private registry:

```
git clone https://github.com/F5Networks/SecondSight
cd SecondSight/f5tt

docker build --no-cache -t PRIVATE_REGISTRY:PORT/f5-telemetry-tracker:latest .
docker push PRIVATE_REGISTRY:PORT/f5-telemetry-tracker:latest
```

Deploy on Kubernetes/Openshift:

```
cd SecondSight/manifests
```

Edit `1.f5tt.yaml` to customize:

- image name:
  - To be set to your private registry image (only if not using the image available on Docker Hub)
- environment variables:

| Variable  | Description |
| ------------- |-------------|
| F5TT_ADDRESS | optional IP address Second Sight should listen on. Default is 0.0.0.0 |
| F5TT_PORT| optional TCP port Second Sight should listen on. Default is 5000 |
| HTTP_PROXY| to be set if proxy for HTTP traffic must be used to connect to NGINX Instance Manager, BIG-IQ and NIST for CVE retrieval. Format must be http://[username:password@]fqdn:port |
| HTTPS_PROXY| to be set if proxy for HTTP traffic must be used to connect to NGINX Instance Manager, BIG-IQ and NIST for CVE retrieval. Format must be https://[username:password@]fqdn:port |
| NIST_API_KEY| API Key for full NIST NVD CVE tracking (get your key at https://nvd.nist.gov/developers/request-an-api-key) |
| DATAPLANE_TYPE| can be NGINX_MANAGEMENT_SYSTEM (NIM 2.x) or BIG_IQ |
| DATAPLANE_FQDN| the FQDN of your NGINX Instance Manager 2.x / BIG-IQ instance| format must be http[s]://FQDN:port |
| DATAPLANE_USERNAME| the username for authentication - optional if DATAPLANE_TYPE=NGINX_MANAGEMENT_SYSTEM and NMS_AUTH_TYPE='jwt' |
| DATAPLANE_PASSWORD| the password for authentication - optional if DATAPLANE_TYPE=NGINX_MANAGEMENT_SYSTEM and NMS_AUTH_TYPE='jwt' |
| NMS_AUTH_TYPE | if DATAPLANE_TYPE=NGINX_MANAGEMENT_SYSTEM (NGINX Instance Manager 2.1.0+) - The authentication type: basic, digest or jwt. "basic" is the default |
| NMS_AUTH_TOKEN | if DATAPLANE_TYPE=NGINX_MANAGEMENT_SYSTEM (NGINX Instance Manager 2.1.0+) - Required if NMS_AUTH_TYPE='jwt': the JWT authentication token |
| NMS_CH_HOST | if DATAPLANE_TYPE=NGINX_MANAGEMENT_SYSTEM (NGINX Instance Manager 2.1.0+) - ClickHouse IP address (optional, default: 127.0.0.1) |
| NMS_CH_HOST | if DATAPLANE_TYPE=NGINX_MANAGEMENT_SYSTEM (NGINX Instance Manager 2.1.0+) - ClickHouse IP address (optional, default: 127.0.0.1) |
| NMS_CH_PORT | if DATAPLANE_TYPE=NGINX_MANAGEMENT_SYSTEM (NGINX Instance Manager 2.1.0+) - ClickHouse TCP port (optional, default: 9000) |
| NMS_CH_USER | if DATAPLANE_TYPE=NGINX_MANAGEMENT_SYSTEM (NGINX Instance Manager 2.1.0+) - ClickHouse username (optional, default: 'default') |
| NMS_CH_PASS | if DATAPLANE_TYPE=NGINX_MANAGEMENT_SYSTEM (NGINX Instance Manager 2.1.0+) - ClickHouse password (optional, default: no password) |
| NMS_SAMPLE_INTERVAL | if DATAPLANE_TYPE=NGINX_MANAGEMENT_SYSTEM instances sample interval in seconds (optional, default: 60) |
| STATS_PUSH_ENABLE | if set to "true" push mode is enabled, disabled if set to "false" |
| STATS_PUSH_MODE | either CUSTOM or PUSHGATEWAY, to push (HTTP POST) JSON to custom URL and to push metrics to pushgateway, respectively |
| STATS_PUSH_URL | the URL where to push statistics |
| STATS_PUSH_INTERVAL | the interval in seconds between two consecutive push |
| STATS_PUSH_USERNAME | (optional) the username for POST Basic Authentication |
| STATS_PUSH_PASSWORD | (optional) the password for POST Basic Authentication |
| EMAIL_ENABLED | if set to "true" automated email reporting is enabled, disabled if set to "false" |
| EMAIL_INTERVAL| the interval in days between two consecutive email reports |
| EMAIL_SERVER | the FQDN of the SMTP server to use |
| EMAIL_SERVER_PORT| the SMTP server port |
| EMAIL_SERVER_TYPE| either "plaintext", "starttls" or "ssl" |
| EMAIL_AUTH_USER| optional, the username for SMTP authentication |
| EMAIL_AUTH_PASS| optional, the password for SMTP authentication |
| EMAIL_SENDER| the sender email address |
| EMAIL_RECIPIENT| the recipient email address |

- Ingress host:
  - By default it is set to `f5tt.ff.lan`

For standalone operations (ie. REST API + optional push to custom URL):

```
kubectl apply -f 0.ns.yaml
kubectl apply -f 1.f5tt.yaml
```

To push statistics to pushgateway also apply:

```
kubectl apply -f 2.prometheus.yaml
kubectl apply -f 3.grafana.yaml
kubectl apply -f 4.pushgateway.yaml
```

By default `2.prometheus.yaml` is configured for push mode, it must be edited decommenting the relevant section for pull mode

To setup visualization:

- Grafana shall be configured with a Prometheus datasource using by default http://prometheus.f5tt.ff.lan
- Import the [sample dashboards](/contrib/grafana) in Grafana

Service names created by default as Ingress resources are:

- `f5tt.ff.lan` - REST API and Prometheus scraping endpoint
- `pushgateway.f5tt.ff.lan` - Pushgateway web GUI
- `prometheus.f5tt.ff.lan` - Prometheus web GUI
- `grafana.f5tt.ff.lan` - Grafana visualization web GUI

# Usage

See the [usage page](/USAGE.md)
