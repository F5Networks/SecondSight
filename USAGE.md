# Second Sight Data Collector Usage

## REST API mode

API Documentation is available at `/docs`, `/redoc` and OpenAPI JSON can be fetched at `/openapi.json`

Main public endpoints are:
- `/instances` or `/f5tt/instances`
- `/metrics` or `/f5tt/metrics`

Endpoints `/instances` and `/f5tt/instances` support response compression if the request includes the `Accept-Encoding: gzip` header

A sample Postman collection is [available here](/contrib/postman)

To get instance statistics in JSON format:

### NGINX Instance Manager 2.x

the `type` query string parameter can be used to retrieve a logical view of the full JSON file:

| Output type | URI | Description |
|---|:---|:---|
| JSON | /instances | NGINX instances inventory, CVE details and time-based usage for last month |
| JSON | /instances?type=CVE | NGINX instances CVE details |
| JSON | /instances?type=timebased&month=M&slot=N |M = 0 to get time-based usage for the current month, -1 for last month (defaults to -1 if not specified) - N = Aggregation based on N-hours timeslot (defaults to 4 if not specified) |

### BIG-IQ

the `type` query string parameter can be used to retrieve a logical view of the full JSON file:

| Output type | URI | Description |
|---|:---|:---|
| JSON | /instances | TMOS devices inventory, CVE details summarized by device and telemetry|
| JSON | /instances?type=CVE | CVE details summarized by CVE |
| JSON | /instances?type=CVEbyDevice | CVE details summarized by device |
| JSON | /instances?type=SwOnHw | "Software on Hardware" report |
| JSON | /instances?type=fullSwOnHw | TMOS devices inventory, CVE details and "Software on Hardware" report |
| JSON | /instances?type=complete | TMOS devices inventory, CVE details summarized by CVE, telemetry |
| JSON | /instances?type=utilityBilling | Utility billing data for hardware units and virtual editions |

- All JSON can be accessed with a browser omitting the `/instances` portion of the URI (ie. `http://f5tt.ff.lan?type=CVE`)

### Prometheus endpoint:

Pulling from NGINX Instance Manager

```
$ curl -s http://f5tt.ff.lan/metrics
# HELP nginx_oss_online_instances Online NGINX OSS instances
# TYPE nginx_oss_online_instances gauge
nginx_oss_online_instances{subscription="NGX-Subscription-1-TRL-064788",instanceType="INSTANCE_MANAGER",instanceVersion="1.0.2",instanceSerial="6232847160738694"} 1
# HELP nginx_plus_online_instances Online NGINX Plus instances
# TYPE nginx_plus_online_instances gauge
nginx_plus_online_instances{subscription="NGX-Subscription-1-TRL-064788",instanceType="INSTANCE_MANAGER",instanceVersion="1.0.2",instanceSerial="6232847160738694"} 0
```

Pulling from BIG-IQ

```
$ curl -s https://f5tt.ff.lan/metrics
# HELP bigip_online_instances Online BIG-IP instances
# TYPE bigip_online_instances gauge
bigip_online_instances{dataplane_type="BIG-IQ",dataplane_url="https://bigiq.f5.ff.lan"} 2
# HELP bigip_hwTotals Total hardware devices count
# TYPE bigip_hwtotals gauge
bigip_hwtotals{dataplane_type="BIG-IQ",dataplane_url="https://bigiq.f5.ff.lan",bigip_sku="F5-VE"} 1
# HELP bigip_swTotals Total software modules count
# TYPE bigip_swtotals gauge
bigip_swtotals{dataplane_type="BIG-IQ",dataplane_url="https://bigiq.f5.ff.lan",bigip_module="H-VE-APM"} 1
bigip_swtotals{dataplane_type="BIG-IQ",dataplane_url="https://bigiq.f5.ff.lan",bigip_module="H-VE-DNS"} 1
bigip_swtotals{dataplane_type="BIG-IQ",dataplane_url="https://bigiq.f5.ff.lan",bigip_module="H-VE-LTM"} 1
bigip_swtotals{dataplane_type="BIG-IQ",dataplane_url="https://bigiq.f5.ff.lan",bigip_module="H-VE-CGNAT"} 1
# HELP bigip_tmos_releases TMOS releases count
# TYPE bigip_tmos_releases gauge
bigip_tmos_releases{dataplane_type="BIG-IQ",dataplane_url="https://bigiq.f5.ff.lan",tmos_release="16.1.0"} 2
# HELP bigip_tmos_cve TMOS CVE count
# TYPE bigip_tmos_cve gauge
bigip_tmos_cve{dataplane_type="BIG-IQ",dataplane_url="https://bigiq.f5.ff.lan",tmos_cve="CVE-2022-23019"} 1
bigip_tmos_cve{dataplane_type="BIG-IQ",dataplane_url="https://bigiq.f5.ff.lan",tmos_cve="CVE-2022-23021"} 1
bigip_tmos_cve{dataplane_type="BIG-IQ",dataplane_url="https://bigiq.f5.ff.lan",tmos_cve="CVE-2022-23032"} 1
bigip_tmos_cve{dataplane_type="BIG-IQ",dataplane_url="https://bigiq.f5.ff.lan",tmos_cve="CVE-2022-23022"} 1
bigip_tmos_cve{dataplane_type="BIG-IQ",dataplane_url="https://bigiq.f5.ff.lan",tmos_cve="CVE-2022-23020"} 1
bigip_tmos_cve{dataplane_type="BIG-IQ",dataplane_url="https://bigiq.f5.ff.lan",tmos_cve="CVE-2022-23016"} 1
bigip_tmos_cve{dataplane_type="BIG-IQ",dataplane_url="https://bigiq.f5.ff.lan",tmos_cve="CVE-2022-23014"} 1
bigip_tmos_cve{dataplane_type="BIG-IQ",dataplane_url="https://bigiq.f5.ff.lan",tmos_cve="CVE-2022-23030"} 1
bigip_tmos_cve{dataplane_type="BIG-IQ",dataplane_url="https://bigiq.f5.ff.lan",tmos_cve="CVE-2022-23025"} 1
bigip_tmos_cve{dataplane_type="BIG-IQ",dataplane_url="https://bigiq.f5.ff.lan",tmos_cve="CVE-2022-23023"} 1
bigip_tmos_cve{dataplane_type="BIG-IQ",dataplane_url="https://bigiq.f5.ff.lan",tmos_cve="CVE-2021-23037"} 1
bigip_tmos_cve{dataplane_type="BIG-IQ",dataplane_url="https://bigiq.f5.ff.lan",tmos_cve="CVE-2021-23043"} 1
```

## Push mode to custom URL

Sample unauthenticated POST payload:

```
POST /callHome HTTP/1.1
Host: 192.168.1.18
User-Agent: python-requests/2.22.0
Accept-Encoding: gzip, deflate
Accept: */*
Connection: keep-alive
Content-Type: application/json
Content-Length: 267

{
  "subscription": {
    "id": "NGX-Subscription-1-TRL-XXXXXX",
    "type": "INSTANCE_MANAGER",
    "version": "1.0.2",
    "serial": "6232847160738694"
  },
  ...
}
```

Sample POST payload with Basic Authentication

```
POST /callHome HTTP/1.1
Host: 192.168.1.18
User-Agent: python-requests/2.22.0
Accept-Encoding: gzip, deflate
Accept: */*
Connection: keep-alive
Content-Type: application/json
Content-Length: 267
Authorization: Basic YWE6YmI=

{
  "subscription": {
    "id": "NGX-Subscription-1-TRL-XXXXXX",
    "type": "INSTANCE_MANAGER",
    "version": "1.0.2",
    "serial": "6232847160738694"
  },
  ...
}
```

## Architecture

High level

```mermaid
graph TD
BIGIQ([BIG-IQ CM]) 
NIM([NGINX Instance Manager])

User([User / external app])
P2S[[Second Sight collector / F5TT]]
GUI[[Second Sight GUI]]
EMAIL([e-mail server])
BROWSER([Browser])
MYF5([External REST endpoint])

TMOSVE([TMOS VE])
BIGIP([BIG-IP])
VIPRION([VIPRION])
NGINXOSS([NGINX OSS])  
NGINXPLUS([NGINX Plus])

P2S -- REST API --> BIGIQ 
P2S -- REST API --> NIM

GUI --> P2S

BIGIQ --> TMOSVE
BIGIQ --> BIGIP
BIGIQ --> VIPRION

NIM --> NGINXOSS
NIM --> NGINXPLUS

User -- REST API --> P2S
P2S -- Usage JSON --> User

P2S -- e-mail w/JSON attachment --> EMAIL

BROWSER -- HTTP --> P2S
P2S -- Grafana Dashboard --> BROWSER
P2S -- Telemetry Call Home --> MYF5
```

JSON telemetry mode

```mermaid
sequenceDiagram
    participant Control Plane
    participant Second Sight
    participant Third party collector
    participant REST API client
    participant Email server

    loop Telemetry aggregation
      Second Sight->>Control Plane: REST API polling
      Second Sight->>Second Sight: Raw data aggregation
    end
    Second Sight->>Third party collector: Push JSON reporting data
    REST API client->>Second Sight: Fetch JSON reporting data
    Second Sight->>Email server: Email with attached JSON reporting data
```

Grafana visualization mode

```mermaid
sequenceDiagram
    participant Control Plane
    participant Second Sight
    participant Pushgateway
    participant Prometheus
    participant Grafana

    loop Telemetry aggregation
      Second Sight->>Control Plane: REST API polling
      Second Sight->>Second Sight: Raw data aggregation
    end
    Second Sight->>Pushgateway: Push telemetry
    Prometheus->>Pushgateway: Scrape telemetry
    Grafana->>Prometheus: Visualization
```
