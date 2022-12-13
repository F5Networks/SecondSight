# Second Sight GUI

Second Sight GUI is currently in active development: GitHub issues can be opened to report bugs.

The GUI walkthrough is [available here](/contrib/GUI/USAGE.md)

# How to deploy

The GUI can be deployed:

- using docker compose 1.29+
- on a Linux virtual machine without docker

```
Second Sight GUI - https://github.com/F5Networks/SecondSight/

 This script is used to deploy/undeploy Second Sight GUI

 === Usage:

 ./secondsight-gui.sh [-h | -c <action> [-s -C cert.pem -K key.pem] | -x]

 === Options:

 -h                                             - This help
 -c [start|stop|restart|deploy|undeploy]        - Deployment command
 -x                                             - Remove backend persistent data

 -s                                             - Publish the GUI using HTTPS (requires cert and key)
 -C [cert.pem]                                  - HTTPS TLS certificate file in .pem format (mandatory with -s)
 -K [key.pem]                                   - HTTPS TLS certificate file in .pem format (mandatory with -s)

 === Examples:

 Deploy HTTPS GUI with Docker compose:  ./secondsight-gui.sh -c start -s -C certfile.pem -K keyfile.pem
 Remove GUI from Docker compose:        ./secondsight-gui.sh -c stop
 Restart and update docker images:      ./secondsight-gui.sh -c restart

 Deploy HTTP GUI on Linux VM:           ./secondsight-gui.sh -c deploy
 Remove GUI from Linux VM:              ./secondsight-gui.sh -c undeploy

 Remove backend data:                   ./secondsight-gui.sh -x
```

## Deployment on a Linux VM without docker:

Deploying to a Linux VM without docker currently supports Ubuntu 22.04 server:

### HTTP mode

```
$ sudo ./secondsight-gui.sh -c deploy
```

The GUI can be accessed browsing to http://<VM_IP_ADDRESS>
Both username and password are set to `admin`

### HTTPS mode

```
$ sudo ./secondsight-gui.sh -c deploy -s -C mycert.crt -K mycert.key
```

The GUI can be accessed browsing to https://<VM_IP_ADDRESS>
Both username and password are set to `admin`

## Removal from a Linux VM without docker:

```
$ sudo ./secondsight-gui.sh -c undeploy
```

## Deployment using docker-compose

### HTTP mode

```
$ ./secondsight-gui.sh -c start
-> Deploying Second Sight GUI
Pulling postgres        ... done
Pulling init-db         ... done
Pulling f5tt            ... done
Pulling secondsight-gui ... done
Pulling nginx           ... done
Creating network "secondsight-gui_default" with the default driver
Creating volume "secondsight-gui_postgres_data" with default driver
Creating postgres        ... done
Creating f5tt            ... done
Creating init-db         ... done
Creating secondsight-gui ... done
Creating nginx           ... done
$
```

The GUI can be accessed browsing to http://<VM_IP_ADDRESS>
Both username and password are set to `admin`

### HTTPS mode

```
$ ./secondsight-gui.sh -c start -s -C mycert.crt -K mycert.key
-> Deploying Second Sight GUI
Pulling postgres        ... done
Pulling init-db         ... done
Pulling f5tt            ... done
Pulling secondsight-gui ... done
Pulling nginx           ... done
Creating network "secondsight-gui_default" with the default driver
Creating volume "secondsight-gui_postgres_data" with default driver
Creating postgres        ... done
Creating f5tt            ... done
Creating init-db         ... done
Creating secondsight-gui ... done
Creating nginx           ... done
$
```

The GUI can be accessed browsing to https://<VM_IP_ADDRESS>
Both username and password are set to `admin`

## Removal using docker-compose

To undeploy Second Sight GUI run:

```
$ ./secondsight-gui.sh -c stop
-> Undeploying Second Sight GUI
Stopping nginx           ... done
Stopping secondsight-gui ... done
Stopping f5tt            ... done
Stopping postgres        ... done
Removing nginx           ... done
Removing secondsight-gui ... done
Removing init-db         ... done
Removing f5tt            ... done
Removing postgres        ... done
Removing network secondsight-gui_default
$
```

## Upgrading using docker-compose

To restart and upgrade Second Sight GUI run:

```
$ ./secondsight-gui.sh -c restart
-> Restarting and updating Second Sight GUI
-> Undeploying Second Sight GUI
Stopping nginx           ... done
Stopping secondsight-gui ... done
Stopping f5tt            ... done
Stopping postgres        ... done
Removing nginx           ... done
Removing secondsight-gui ... done
Removing init-db         ... done
Removing f5tt            ... done
Removing postgres        ... done
Removing network secondsight-gui_default
-> Deploying Second Sight GUI
Pulling postgres        ... done
Pulling init-db         ... done
Pulling f5tt            ... done
Pulling secondsight-gui ... done
Pulling nginx           ... done
Creating network "secondsight-gui_default" with the default driver
Creating f5tt     ... done
Creating postgres ... done
Creating init-db  ... done
Creating secondsight-gui ... done
Creating nginx           ... done
$
```
