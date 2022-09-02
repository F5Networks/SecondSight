# Second Sight GUI

Second Sight GUI is currently in beta release and not all features are complete/available yet: GitHub issues can be opened to report bugs.

The GUI walkthrough is [available here](/contrib/GUI/USAGE.md)

# How to deploy

The GUI can be deployed using docker compose 1.29+ on a Linux virtual machine running Docker:

```
$ ./secondsight-gui.sh 
Second Sight GUI - https://github.com/F5Networks/SecondSight/

 This script is used to deploy/undeploy Second Sight GUI using docker-compose

 === Usage:

 ./secondsight-gui.sh [options]

 === Options:

 -h                     - This help
 -c [start|stop]        - Deployment command
 -x                     - Remove backend persistent data

 === Examples:

 Deploy Second Sight GUI:       ./secondsight-gui.sh -c start
 Remove Second Sight GUI:       ./secondsight-gui.sh -c stop
 Remove backend data:           ./secondsight-gui.sh -x
```

## Deployment

```
$ ./secondsight-gui.sh -c start
-> Deploying Second Sight GUI
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

## Removal

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
