# GUI Walkthrough

1. Login using username "admin" and password "admin"

<img src="/contrib/GUI/screenshots/1.login.png"/>

2. The "Datafile upload" section can be used to upload:
  - [BIG-IQ offline collection tgz files](https://github.com/F5Networks/SecondSight/tree/main/contrib/bigiq-collect)
  - [BIG-IQ "full" JSON files, /instances endpoint](https://github.com/F5Networks/SecondSight/blob/main/USAGE.md#big-iq)
  - [BIG-IP offline collection JSON files](https://github.com/F5Networks/SecondSight/tree/main/contrib/bigip-collect)
  - [NGINX Management Suite "full" JSON files, /instances endpoint](https://github.com/F5Networks/SecondSight/blob/main/USAGE.md#nginx-instance-manager-2x)

<img src="/contrib/GUI/screenshots/2.upload.png"/>

3. The "Archive" section displays the list of all loaded BIG-IQ and NGINX data collections. Filtering/search and sorting capabilities are available

<img src="/contrib/GUI/screenshots/3.archive.png"/>

4. The "Dashboard" section is used to display analytics, drill down into TMOS devices, NGINX instances details and display NGINX instances usage

<img src="/contrib/GUI/screenshots/4.bigiq-swhw.png"/>
<img src="/contrib/GUI/screenshots/5.bigiq-telemetry.png"/>
<img src="/contrib/GUI/screenshots/6.nginx-analytics.png"/>
<img src="/contrib/GUI/screenshots/7.nginx-releases.png"/>
<img src="/contrib/GUI/screenshots/8.nginx-timebased.png"/>

5. The "BIG-IP" section aggregates assets data pushed directly by TMOS instances (BIG-IP, VIPRION, Virtual Edition) to Second Sight. The analytics dashboard can be accessed from here.

<img src="/contrib/GUI/screenshots/10.bigip-list.png"/>
<img src="/contrib/GUI/screenshots/11.bigip-analytics.png"/>

5. The "Reports" section is used to download reports in JSON, PDF, XLS, PPTX, DOCX and CSV format for TMOS devices and NGINX instances

<img src="/contrib/GUI/screenshots/9.reporting.png"/>
