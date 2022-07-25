# Second Sight for NGINX Instance Manager on Kubernetes

This manifest can be used to run Second Sight on Kubernetes to track usage and telemetry from a NGINX Instance Manager instance. It can be used for ELA (Enterprise License Agreement) and FCP (Flexible Consumption Program) tracking.

To run:

1. **Edit the `f5tt-nim.yaml` manifest and customize sections marked with `############ CONFIGURE HERE ############`**

NGINX Instance Manager URL and authentication credentials:

```
          ############ CONFIGURE HERE ############
          - name: DATAPLANE_FQDN
            value: "https://nim2.f5.ff.lan"
          - name: DATAPLANE_USERNAME
            value: "admin"
          - name: DATAPLANE_PASSWORD
            value: "nimadmin"
          ############ CONFIGURE HERE ############
```

Second Sight ingress hostname:

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: f5tt
  namespace: f5tt-nim
  labels:
    app: f5tt
spec:
  rules:
    ############ CONFIGURE HERE ############
    - host: f5tt.ff.lan
    ############ CONFIGURE HERE ############
```

Grafana domain and URL:

```
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-config
  namespace: f5tt-nim
data:
  grafana.ini: |-
    [paths]
    [server]
    ############ CONFIGURE HERE ############
    domain = grafana.ff.lan
    root_url = https://grafana.ff.lan
    ############ CONFIGURE HERE ############
```

Grafana ingress hostname:

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: f5tt-nim
  labels:
    app: grafana
spec:
  rules:
    ############ CONFIGURE HERE ############
    - host: grafana.ff.lan
    ############ CONFIGURE HERE ############
      http:
```

2. **Apply the manifest**

```
$ kubectl apply -f f5tt-nim.yaml 
namespace/f5tt-nim created
configmap/clickhouse-config created
persistentvolumeclaim/pvc-clickhouse-data created
persistentvolumeclaim/pvc-clickhouse-logs created
deployment.apps/clickhouse created
service/clickhouse created
deployment.apps/f5tt created
service/f5tt created
ingress.networking.k8s.io/f5tt created
configmap/prometheus-config created
persistentvolumeclaim/pvc-prometheus created
deployment.apps/prometheus created
service/prometheus created
configmap/grafana-config created
persistentvolumeclaim/pvc-grafana-data created
persistentvolumeclaim/pvc-grafana-log created
deployment.apps/grafana created
service/grafana created
ingress.networking.k8s.io/grafana created

```

3. **Second Sight is up and running**

```
$ kubectl get pods -n f5tt-nim
NAME                          READY   STATUS    RESTARTS   AGE
clickhouse-555b99ff54-ddl8z   1/1     Running   0          12s
f5tt-67fb4b54-ssqrh           1/1     Running   0          12s
grafana-db7449746-7pntc       1/1     Running   0          12s
prometheus-66bd797849-9fknz   1/1     Running   0          12s
```

4. **The `f5tt` ingress can be used to fetch the usage JSON file** - the ingress FQDN can be customized (see step 1 here above)

```
$ kubectl get ingress -n f5tt-nim
NAME      CLASS   HOSTS            ADDRESS   PORTS   AGE
f5tt      nginx   f5tt.ff.lan                80      66s
grafana   nginx   grafana.ff.lan             80      66s
```

```
$ curl -s "http://f5tt.ff.lan/instances?type=timebased" | jq
{
  "subscription": {
    "id": "NGX-Subscription-1-TRL-XXXXXX",
    "type": "INSTANCE_MANAGER",
    "version": "",
    "serial": ""
  },
  "instances": [
    {
      "ts": {
        "from": "2022-06-08 22:36:24",
        "to": "2022-06-08 22:40:36"
      },
      "nginx_oss": {
        "managed": "1",
        "online": "1",
        "offline": "0"
      },
      "nginx_plus": {
        "managed": "4",
        "online": "4",
        "offline": "0"
      },
      "modules": {
        "ngx_http_app_protect_module": "2",
        "ngx_http_app_protect_dos_module": "",
        "ngx_http_js_module": "4",
        "ngx_stream_js_module": "4"
      }
    }
  ]
}
```

5. **For full usage information see the [usage page](/USAGE.md)**
