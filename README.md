# Second Sight

Second Sight is a comprehensive tool to track assets for NGINX Opensource, NGINX Plus and TMOS devices.

Available data collectors are:

- [BIG-IQ collector](/contrib/bigiq-collect) - gathers raw data for devices managed by BIG-IQ
- [BIG-IP collector](/contrib/bigip-collect) - gathers raw data from BIG-IP devices/virtual editions
- [NGINX collector for Linux](/F5TT.md) - gathers raw data from NGINX Instance Manager
- [NGINX collector for Kubernetes](/contrib/kubernetes) - gathers raw data from NGINX Instance Manager

## Description and features

Raw data is collected from NGINX Instance Manager, BIG-IQ and TMOS instances to provide visibility and insights on:

- Software usage
- Hardware usage
- Operating system and software releases
- Realtime CVE tracking
- Telemetry data (CPU, RAM, disk, network throughput, ...)
- Analytics and drill-down
- vCMP hosts and guests map (for BIG-IP and VIPRION)
- NGINX modules (for NGINX OSS and NGINX Plus)
- Time-based usage reporting (for NGINX OSS, NGINX Plus, NGINX App Protect WAF and NGINX App Protect WAF DoS)

Second Sight has been tested on:

- NGINX Instance Manager 2.1.0+
- BIG-IQ 8.1.0, 8.1.0.2, 8.2.0, 8.3.0
- TMOS 14+

## F5 Support solutions

See F5 Support solutions:

- [K83394355: How to count the number of NGINX instances with Second Sight on NGINX Instance Manager](https://support.f5.com/csp/article/K83394355)
- [K29144504: How to install and use (Offline) Second Sight collection Script on BIG-IQ](https://support.f5.com/csp/article/K29144504)
- [K94129313: How to install and use Docker Second Sight collection script on BIG-IQ](https://support.f5.com/csp/article/K94129313)

## Additional tools

Additional tools can be found [here](/contrib)
