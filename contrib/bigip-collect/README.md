# BIG-IP Collector

## Description

The `bigIPCollect.sh` script must be copied and run on a BIG-IP instance (hardware-based or Virtual Edition). It will collect raw data and package them into a JSON file that can be processed offline by Second Sight.

## Installation on BIG-IP

- Copy (scp) `bigIPCollect.sh` from your local host to your BIG-IP instance, under `/tmp/`

```
$ scp bigIPCollect.sh root@bigip1.f5:/tmp/
(root@bigip1.f5) Password: 
bigIPCollect.sh                              100% 1611   789.7KB/s   00:00    
$ 
```

- SSH to your BIG-IP instance and run the collection script with no parameters to display the help banner

```
$ ssh root@bigip1.f5
(root@bigip1.f5) Password: 
Last login: Fri Nov 19 00:00:05 2021 from 192.168.1.18
[root@bigiq:Active:Standalone] config # chmod +x /tmp/bigIPCollect.sh 
[root@bigiq:Active:Standalone] config # /tmp/bigIPCollect.sh 
Second Sight - https://github.com/F5Networks/SecondSight

 This tool collects usage tracking data from BIG-IP for offline postprocessing.

 === Usage:

 ./bigIPCollect.sh [options]

 === Options:

 -h             - This help
 -i             - Interactive mode
 -u [username]  - BIG-IP username (batch mode)
 -p [password]  - BIG-IP password (batch mode)
 -s [http(s)://address] - Upload data to Second Sight (optional)

 === Examples:

 Interactive mode:
        ./bigIPCollect.sh -i
        ./bigIPCollect.sh -i -s https://<SECOND SIGHT GUI ADDRESS>

 Batch mode:
        ./bigIPCollect.sh -u [username] -p [password]
        ./bigIPCollect.sh -u [username] -p [password] -s https://<SECOND SIGHT GUI ADDRESS>
```

## Automated data collection

- On BIG-IP run the collection script using "admin" as the authentication username and its password

```
[root@bigip1:Active:Disconnected] tmp # ./bigIPCollect.sh -i -s http://192.168.1.19:8080
Username: admin
Password: 
-> Collecting global settings
-> Collecting management details
-> Collecting license info
-> Collecting software details
-> Collecting hardware details
-> Collecting provisioned modules
-> Collecting APM usage
-> Data collection completed, building JSON payload
-> Uploading /tmp/20230322-1154-bigIPCollect.json to Second Sight at http://192.168.1.19:8080
{"success":true,"status":"File upload completed","filename":"20230322-1154-bigIPCollect.json","content-type":"application/octet-stream","description":"20230322-1154-bigIPCollect.json","uid":"73096b05-995f-43cd-be8d-6fc39100c839"}
-> Upload complete
[root@bigip1:Active:Disconnected] tmp #
```

## Manual data collection

- On BIG-IP run the collection script using "admin" as the authentication username and its password

```
[root@bigip1:Active:Disconnected] tmp # ./bigIPCollect.sh -i
Username: admin
Password: 
-> Collecting global settings
-> Collecting management details
-> Collecting license info
-> Collecting software details
-> Collecting hardware details
-> Collecting provisioned modules
-> Collecting APM usage
-> Data collection completed, building JSON payload
-> All done, copy /tmp/20230626-0002-bigIPCollect.json to your local host using scp
[root@bigip1:Active:Disconnected] tmp #
```

- Retrieve the JSON file

```
$ scp root@bigip.f5:/tmp/20230626-0002-bigIPCollect.json .
(root@bigip.f5) Password: 
20230626-0002-bigIPCollect.json               100%   14KB   5.4MB/s   00:00    
$ 
```
