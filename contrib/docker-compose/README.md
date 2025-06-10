# Docker compose

Second Sight can be deployed using docker compose on a Linux virtual machine running Docker.

This docker compose version creates a `/opt/f5tt` working directory for persistent storage.

Usage:

```
$ git clone https://github.com/F5Networks/SecondSight
$ cd SecondSight/contrib/docker-compose
$ ./f5tt-compose.sh 
Second Sight - https://github.com/F5Networks/SecondSight/

 This script is used to deploy/remove Second Sight with docker-compose

 === Usage:

 ./f5tt-compose.sh [options]

 === Options:

 -h                     - This help

 -c [start|stop]        - Deployment command
 -t [bigiq|nim]         - Deployment type

 -s [url]               - BIG-IQ URL
 -u [username]          - BIG-IQ username
 -p [password]          - BIG-IQ password

 -k [NIST API key]      - NIST CVE REST API Key (https://nvd.nist.gov/developers/request-an-api-key)

 === Examples:

 Deploy Second Sight for BIG-IQ:                        ./f5tt-compose.sh -c start -t bigiq -s https://<BIGIQ_ADDRESS> -u <username> -p <password>
 Remove Second Sight for BIG-IQ:                        ./f5tt-compose.sh -c stop -t bigiq
```

## How to deploy

1. Use docker-compose on a Linux VM running docker to start the BIG-IQ deployment
2. Access the setup:
  - Grafana: Using a browser access `http://<VM_IP_ADDRESS>`
  - Second Sight: Access endpoints `http://<VM_IP_ADDRESS>/f5tt/instances` and `http://<VM_IP_ADDRESS>/f5tt/metrics` - See the [usage page](/USAGE.md)
3. Log on using username `admin` and password `admin`, then set a new password
4. Browse to `http://<VM_IP_ADDRESS>/dashboard/import` Import the dashboards selecting the preconfigured "Prometheus" datasource
  - [BIG-IQ dashboard](/contrib/grafana/F5TT-BIGIQ.json)
6. After ~120 seconds the dashboards will be available


## Starting & stopping with docker-compose

Starting Second Sight for BIG-IQ:

```
$ ./f5tt-compose.sh -c start -t bigiq -s https://<BIGIQ_ADDRESS> -u admin -p mypassword
-> Deploying Second Sight for bigiq at https://<BIGIQ_ADDRESS>
Enter sudo password if prompted
Password: 
Creating network "f5tt-bigiq_default" with the default driver
Creating f5tt-bigiq ... done
Creating prometheus ... done
Creating nginx      ... done
Creating grafana    ... done
$
```

Stopping Second Sight for BIG-IQ:

```
$ ./f5tt-compose.sh -c stop -t bigiq
-> Undeploying Second Sight for bigiq
Stopping grafana    ... done
Stopping f5tt-bigiq ... done
Stopping nginx      ... done
Stopping prometheus ... done
Removing grafana    ... done
Removing f5tt-bigiq ... done
Removing nginx      ... done
Removing prometheus ... done
Removing network f5tt-bigiq_default
$
```
