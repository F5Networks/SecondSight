import os
import sys
import ssl
import json
import sched,time,datetime
import requests
import time
import threading
import smtplib
import urllib3.exceptions
import base64
from io import BytesIO
from requests import Request, Session
from requests.packages.urllib3.exceptions import InsecureRequestWarning
from email.message import EmailMessage
from dateutil.relativedelta import relativedelta

import cveDB
import utils

this = sys.modules[__name__]

requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

# Hardware platform types, names and SKU mappings
# https://support.f5.com/csp/article/K4309
hwPlatforms = {
  "D110": "7250|F5-BIG-7250",
  "D113": "10200|F5-BIG-10200",
  "C113": "4200|F5-BIG-4200",
  "D116": "I15800|F5-BIG-I15800",
  "C124": "I11800|F5-BIG-I11800-DS",
  "C123": "I11800|F5-BIG-I11800",
  "    ": "I10800|F5-BIG-I10800-D",
  "C116": "I10800|F5-BIG-I10800",
  "C126": "I7820-DF|F5-BIG-I7820-DF",
  "    ": "I7800|F5-BIG-I7800-D",
  "C118": "I7800|F5-BIG-I7800",
  "C125": "I5820-DF|F5-BIG-I5820-DF",
  "C119": "I5800|F5-BIG-I5800",
  "C115": "I4800|F5-BIG-I4800",
  "C117": "I2800|F5-BIG-I2800",
  "    ": "C4800|F5-VPR-C4800-DCN",
  "A109": "B2100|F5-VPR-B2100",
  "A113": "B2150|F5-VPR-B2150",
  "A112": "B2250|F5-VPR-B2250",
  "A114": "B4450|F5-VPR-B4450N",
  "F100": "C2400|F5-VPR-C2400-AC",
  "F101": "C2400|F5-VPR-C2400-AC",
  "    ": "C2400|F5-VPR-C2400-ACT",
  "J102": "C4480|F5-VPR-C4480-AC",
  "    ": "C4480|F5-VPR-C4480-DCN",
  "S100": "C4800|F5-VPR-C4800-AC",
  "S101": "C4800|F5-VPR-C4800-AC",
  "Z100": "VE|F5-VE",
  "Z101": "VE-VCMP|F5-VE-VCMP"
}

# TMOS modules SKU
swModules = {
  "gtm": "DNS",
  "sslo": "SSLO",
  "apm": "APM",
  "cgnat": "CGNAT",
  "ltm": "LTM",
  "avr": "",
  "fps": "",
  "dos": "",
  "lc": "",
  "pem": "PEM",
  "urldb": "",
  "swg": "",
  "asm": "AWF",
  "afm": "AFM",
  "ilx": ""
}

this.bigiq_fqdn=''
this.bigiq_username=''
this.bigiq_password=''
this.bigiq_proxy={}

# Module initialization
def init(fqdn,username,password,proxy,nistApiKey):
  this.bigiq_fqdn=fqdn
  this.bigiq_username=username
  this.bigiq_password=password
  this.bigiq_proxy=proxy

  cveDB.init(nistApiKey=nistApiKey,proxy=proxy)


# Thread for scheduled inventory generation
def scheduledInventory():
  while True:
    # Starts inventory generation task
    # https://clouddocs.f5.com/products/big-iq/mgmt-api/v8.1.0/HowToSamples/bigiq_public_api_wf/t_export_device_inventory.html?highlight=inventory
    print(datetime.datetime.now(),"Requesting BIG-IQ inventory refresh")
    res,body = bigIQcallRESTURI(method = "POST", uri = "/mgmt/cm/device/tasks/device-inventory", body = {'devicesQueryUri': 'https://localhost/mgmt/shared/resolver/device-groups/cm-bigip-allBigIpDevices/devices'} )

    time.sleep(86400)


### BIG-IQ REST API

# Returns BIG-IP devices managed by BIG-IQ
def bigIQInstances():
  return bigIQcallRESTURI(method = "GET",uri = "/mgmt/shared/resolver/device-groups/cm-bigip-allBigIpDevices/devices",body = "")


# Returns details for a given BIG-IP device
def bigIQInstanceDetails(instanceUUID):
  return bigIQcallRESTURI(method = "GET",uri = "/mgmt/cm/system/machineid-resolver/"+instanceUUID, body = "")


# Returns modules provisioning status details for BIG-IP devices managed by BIG-IQ
def bigIQInstanceProvisioning():
  return bigIQcallRESTURI(method = "GET",uri = "/mgmt/cm/shared/current-config/sys/provision", body ="")


# Returns the most recent inventory for BIG-IP devices managed by BIG-IQ
def bigIQgetInventory():
  # Gets the latest available inventory
  # The "resultsReference" field contains the URL to fetch license/serial number information
  res,body = bigIQcallRESTURI(method = "GET", uri = "/mgmt/cm/device/tasks/device-inventory", body = "" )
  if res != 200:
    return res,body
  else:
    latestUpdate=0
    latestResultsReference=''
    for item in body['items']:
      if item['lastUpdateMicros'] > latestUpdate:
        # "resultsReference": {
        #   "link": "https://localhost/mgmt/cm/device/reports/device-inventory/8982ed9f-1870-4483-96c2-9fb024a2a5b6/results",
        #   "isSubcollection": true
        # }
        if 'resultsReference' in item:
          latestResultsReference = item['resultsReference']['link'].split('/')[8]
          latestUpdate = item['lastUpdateMicros']

    if latestUpdate == 0:
       return 204,'{}'

    res,body = bigIQcallRESTURI(method = "GET", uri = "/mgmt/cm/device/reports/device-inventory/"+latestResultsReference+"/results", body = "" )

    return res,body


# Returns all utility licenses
def bigIQGetLicenses():
  return bigIQcallRESTURI(method = "GET",uri = "/mgmt/cm/device/licensing/pool/utility/licenses", body = "", params = { '$select': 'regKey,status' })


# Create billing report request
def bigIQCreateBillingReport(regKey):
  return bigIQcallRESTURI(method = "POST", uri = "/mgmt/cm/device/tasks/licensing/utility-billing-reports", body = {'regKey': regKey, 'submissionMethod': 'Automatic' } )


# Get billing report status
def bigIQCheckBillingReport(reportId):
  return bigIQcallRESTURI(method = "GET", uri = "/mgmt/cm/device/tasks/licensing/utility-billing-reports/"+reportId, body = "" )


# Fetch billing report
def bigIQFetchBillingReport(reportFile):
  return bigIQcallRESTURI(method = "GET", uri = "/mgmt/cm/device/licensing/license-reports-download/"+reportFile, body = "" )


# Invokes the given BIG-IQ REST API method
# The uri must start with '/'
def bigIQcallRESTURI(method,uri,body,params=""):
  # Get authorization token
  time.sleep(0.04)
  authRes = requests.request("POST", this.bigiq_fqdn+"/mgmt/shared/authn/login", json = {'username': this.bigiq_username, 'password': this.bigiq_password}, verify=False, proxies=this.bigiq_proxy)

  if authRes.status_code != 200:
    return authRes.status_code,authRes.json()
  authToken = authRes.json()['token']['token']

  # Invokes the BIG-IQ REST API method
  time.sleep(0.04)
  res = requests.request(method, this.bigiq_fqdn+uri, headers = { 'X-F5-Auth-Token': authToken }, json = body, verify=False, proxies=this.bigiq_proxy, params=params)

  data = {}
  if res.status_code == 200 or res.status_code == 202:
    if res.content != '':
      data = res.json()

  return res.status_code,data


### BIG-IQ query functions

# Returns TMOS instances managed by BIG-IQ in JSON format
def bigIqInventory(mode):

  status,details = bigIQInstances()
  if status != 200:
    return details,status

  # Gets TMOS modules provisioning state for all devices
  rcode,provisioningDetails = bigIQInstanceProvisioning()
  rcode2,inventoryDetails = bigIQgetInventory()

  hwSKUGrandTotals={}
  swSKUGrandTotals={}
  wholeInventory=[]

  if "items" in details:
    for item in details['items']:
      # Gets TMOS registration key and serial number for the current BIG-IP device
      inventoryData = {}

      # Check for failed inventory
      if 'lastUpdateMicros' in inventoryDetails:
        inventoryData['inventoryTimestamp'] = inventoryDetails['lastUpdateMicros']//1000

      platformType=''

      if rcode2 == 204:
        inventoryData['inventoryStatus']="partial"
      else:
        machineIdFound=False

        # Check for failed inventory
        if 'items' in inventoryDetails:
          for invDevice in inventoryDetails['items']:
            if invDevice['infoState']['machineId'] == item['machineId']:
              machineIdFound=True
              if "errors" in invDevice['infoState']:
                # BIG-IP unreachable, inventory incomplete
                inventoryData['inventoryStatus']="partial"
              else:
                # Get platform name and SKU
                if 'platform' in invDevice['infoState']:
                  platformCode=invDevice['infoState']['platform']
                  platformInsights={}
                  if platformCode in hwPlatforms:
                    platformDetails=hwPlatforms[platformCode]
                    platformType=platformDetails.split('|')[0]
                    platformSKU=platformDetails.split('|')[1]

                    if platformSKU in hwSKUGrandTotals:
                      hwSKUGrandTotals[platformSKU] += 1
                    else:
                      hwSKUGrandTotals[platformSKU] = 1

                    platformInsights['type']=platformType
                    platformInsights['sku']=platformSKU

                platformInsights['code']=platformCode

                inventoryData['inventoryStatus'] = "full"
                inventoryData['registrationKey'] = invDevice['infoState']['license']['registrationKey'] if 'registrationKey' in invDevice['infoState']['license'] else ''

                activeModulesArray = invDevice['infoState']['license']['activeModules'] if 'activeModules' in invDevice['infoState']['license'] else ''
                inventoryData['activeModules'] = activeModulesArray
                inventoryData['elaPlatform'] = ''
                elaPlatformType = ''

                for am in activeModulesArray:
                  if am.startswith('ELA,'):
                    inventoryData['elaPlatform'] = am.split('|')[0]
                    elaPlatformType = am.split('|')[0].split(' ')[1].upper()

                if 'chassisSerialNumber' in invDevice['infoState']:
                  inventoryData['chassisSerialNumber'] = invDevice['infoState']['chassisSerialNumber'].strip()
                else:
                  inventoryData['chassisSerialNumber'] = ""
                inventoryData['platform'] = platformInsights

                if 'licenseEndDateTime' in invDevice['infoState']['license']:
                  inventoryData['licenseEndDateTime']=invDevice['infoState']['license']['licenseEndDateTime']

        if machineIdFound == False:
          inventoryData['inventoryStatus']="partial"

      # Gets TMOS modules provisioning for the current BIG-IP device
      # https://support.f5.com/csp/article/K4309
      provModules = {}
      provModules['provisionedModules']=[]

      foundCVEs={}

      for prov in provisioningDetails['items']:
        if prov['deviceReference']['machineId'] == item['machineId']:

          # Retrieving relevant SKUs and platform types
          moduleProvisioningLevel=''

          if prov['name'] in swModules:
            moduleName = swModules[prov['name']]
          else:
            moduleName = ''

          if platformType == '' or moduleName == '':
            moduleSKU = ''
          else:
            if platformType == 'VE-VCMP':
              moduleSKU = elaPlatformType + '-' + moduleName
            else:
              moduleSKU = platformType + "-" + moduleName

            moduleProvisioningLevel=prov['level']

            if moduleProvisioningLevel != 'none':
              # CVE tracking
              allCVE=cveDB.getF5(product=prov['name'],version=item['version'])
              foundCVEs.update(allCVE)

              if moduleSKU in swSKUGrandTotals:
                swSKUGrandTotals[moduleSKU] += 1
              else:
                swSKUGrandTotals[moduleSKU] = 1

          thisModule = {}
          thisModule['module']=prov['name']
          thisModule['level']=moduleProvisioningLevel
          thisModule['sku']=moduleSKU

          provModules['provisionedModules'].append(thisModule)

      # Gets TMOS licensed modules for the current BIG-IP device
      retcode,instanceDetails = bigIQInstanceDetails(item['machineId'])

      if retcode == 200:
        if instanceDetails != '':
          licensedModules = instanceDetails['properties']['cm:gui:module']

          platformMarketingName=''
          if 'platformMarketingName' in item:
            platformMarketingName=item['platformMarketingName']

          inventoryData['hostname']=item['hostname']
          inventoryData['address']=item['address']
          inventoryData['product']=item['product']
          inventoryData['version']=item['version']
          inventoryData['edition']=item['edition']
          inventoryData['build']=item['build']
          inventoryData['isVirtual']=item['isVirtual']
          inventoryData['isClustered']=item['isClustered']
          inventoryData['platformMarketingName']=platformMarketingName
          inventoryData['machineId']=item['machineId']
          inventoryData['restFrameworkVersion']=item['restFrameworkVersion']
          inventoryData['licensedModules']=licensedModules
          inventoryData['provisionedModules']=provModules['provisionedModules']
          inventoryData['CVE']=[]
          inventoryData['CVE'].append(foundCVEs)

          wholeInventory.append(inventoryData)

  # Full JSON creation

  instancesDict = {}
  if "items" in details:
    instancesDict['bigip']=len(details['items'])
  else:
    instancesDict['bigip']=0
  instancesDict['hwTotals'] = []
  instancesDict['hwTotals'].append(hwSKUGrandTotals)
  instancesDict['swTotals'] = []
  instancesDict['swTotals'].append(swSKUGrandTotals)

  output = {}
  output['report'] = utils.getVersionJson(reportType='Full',dataplane='BIG-IQ')

  timeNow = datetime.datetime.now()
  monthAgo = timeNow - datetime.timedelta(days=30)
  monthAgoEnd = timeNow.replace(day=1,hour=0,minute=0,second=0) - datetime.timedelta(seconds=1)

  output['periodStarted'] = monthAgo.replace(day=1,hour=0,minute=0,second=0).strftime("%Y-%m-%dT%H:%M:%SZ")
  output['periodEnded'] = monthAgoEnd.strftime("%Y-%m-%dT%H:%M:%SZ")

  output['instances'] = []
  output['instances'].append(instancesDict)
  output['details'] = wholeInventory
  output['telemetry'] = []
  output['telemetry'] = bigIqTelemetry(mode)
  output['utilityBilling'] = bigIQCollectUtilityBilling()

  # JSON mode
  if mode == 'JSON':
    return output,200

  # PROMETHEUS or PUSHGATEWAY mode
  metricsOutput = ''
  metricsOutput += '# HELP bigip_online_instances Online BIG-IP instances\n# TYPE bigip_online_instances gauge\n' if (mode == 'PROMETHEUS') else ''
  metricsOutput += 'bigip_online_instances{dataplane_type="BIG-IQ",dataplane_url="'+bigiq_fqdn+'"} '+str(output['instances'][0]['bigip'])+'\n'

  # Hardware totals
  metricsOutput += '# HELP bigip_hwTotals Total hardware devices count\n# TYPE bigip_hwtotals gauge\n' if (mode == 'PROMETHEUS') else ''
  for hwT in output['instances'][0]['hwTotals'][0]:
    metricsOutput += 'bigip_hwtotals{dataplane_type="BIG-IQ",dataplane_url="'+bigiq_fqdn+'",bigip_sku="'+hwT+'"} '+str(output['instances'][0]['hwTotals'][0][hwT])+'\n'

  # Software totals
  metricsOutput += '# HELP bigip_swTotals Total software modules count\n# TYPE bigip_swtotals gauge\n' if (mode == 'PROMETHEUS') else ''
  for swT in output['instances'][0]['swTotals'][0]:
    metricsOutput += 'bigip_swtotals{dataplane_type="BIG-IQ",dataplane_url="'+bigiq_fqdn+'",bigip_module="'+swT+'"} '+str(output['instances'][0]['swTotals'][0][swT])+'\n'

  # TMOS releases and CVE
  tmosRel = {}
  cves = {}
  for d in output['details']:
    if d['version'] in tmosRel:
      tmosRel[d['version']] += 1
    else:
      tmosRel[d['version']] = 1

    metricsOutput += '# HELP bigip_tmos_cve_details TMOS CVE details\n# TYPE bigip_tmos_cve_details counter\n' if (mode == 'PROMETHEUS') else ''
    for c in d['CVE'][0]:
      metricsOutput += 'bigip_tmos_cve_details{dataplane_type="BIG-IQ",dataplane_url="'+bigiq_fqdn+ \
        '",hostname="'+d['hostname']+ \
        '",tmos_cve="'+c+ \
        '",severity="'+str(d['CVE'][0][c]['baseSeverity'])+ \
        '",base_score="'+str(d['CVE'][0][c]['baseScore'])+ \
        '",exploitability_score="'+str(d['CVE'][0][c]['exploitabilityScore'])+ \
        '"} '+str(d['CVE'][0][c]['baseScore'])+'\n'
      if c in cves:
        cves[c] += 1
      else:
        cves[c] = 1

  # TMOS releases
  metricsOutput += '# HELP bigip_tmos_releases TMOS releases count\n# TYPE bigip_tmos_releases gauge\n' if (mode == 'PROMETHEUS') else ''
  for v in tmosRel:
    metricsOutput += 'bigip_tmos_releases{dataplane_type="BIG-IQ",dataplane_url="'+bigiq_fqdn+'",tmos_release="'+v+'"} '+str(tmosRel[v])+'\n'

  # CVE totals
  metricsOutput += '# HELP bigip_tmos_cve TMOS CVE count\n# TYPE bigip_tmos_cve gauge\n' if (mode == 'PROMETHEUS') else ''
  for c in cves:
    metricsOutput += 'bigip_tmos_cve{dataplane_type="BIG-IQ",dataplane_url="'+bigiq_fqdn+'",tmos_cve="'+c+'"} '+str(cves[c])+'\n'

  # TMOS Telemetry
  telemetry = bigIqTelemetry('PROMETHEUS')
  metricsOutput += telemetry

  return metricsOutput,200


# Returns the CVE-centric JSON, summarized by CVE
def bigIqCVEjson(fullJSON=None):
  if fullJSON is None:
    fullJSON,retcode = bigIqInventory(mode='JSON')

  cveJSON = {}
  cveJSON['report'] = utils.getVersionJson(reportType='CVE',dataplane='BIG-IQ')

  for d in fullJSON['details']:
    bigipHostname = d['hostname']
    bigipVersion = d['version']

    for cve in d['CVE'][0]:
      if cve not in cveJSON:
        cveJSON[cve] = d['CVE'][0][cve]
        cveJSON[cve]['devices'] = []

      deviceJSON = {}
      deviceJSON['hostname'] = bigipHostname
      deviceJSON['version'] = bigipVersion

      cveJSON[cve]['devices'].append(deviceJSON)

  return cveJSON,200


# Returns the CVE-centric JSON, summarized by device
def bigIqCVEbyDevicejson(fullJSON=None):
  if fullJSON is None:
    fullJSON,retcode = bigIqInventory(mode='JSON')
  devicecveJSON = {}
  devicecveJSON['report'] = utils.getVersionJson(reportType='CVE by Device',dataplane='BIG-IQ')

  for d in fullJSON['details']:
    thisDevice = {}
    thisDevice['hostname'] = d['hostname']
    thisDevice['chassisSerialNumber'] = d['chassisSerialNumber'] if 'chassisSerialNumber' in d else ''
    thisDevice['version'] = d['version']
    thisDevice['CVE'] = []

    for cve in d['CVE'][0]:
      c = d['CVE'][0][cve]
      thisCVE = {}
      thisCVE['id'] = c['id']
      thisCVE['url'] = c['url']
      thisCVE['baseSeverity'] = c['baseSeverity']
      thisCVE['baseScore'] = c['baseScore']
      thisCVE['exploitabilityScore'] = c['exploitabilityScore']

      thisDevice['CVE'].append(thisCVE)

    devicecveJSON[d['hostname']]=thisDevice

  return devicecveJSON,200


# Returns the software on hardware JSON
def bigIqSwOnHwjson(fullJSON=None):
  if fullJSON is None:
    fullJSON,retcode = bigIqInventory(mode='JSON')
  swOnHwJSON = []

  vCMPHostModules = {}

  for d in fullJSON['details']:
    if d['inventoryStatus'] == "full":
      deviceJSON = {}

      bigipSN = d['chassisSerialNumber'] if 'chassisSerialNumber' in d else ''
      bigipRegKey = d['registrationKey'] if 'registrationKey' in d else ''
      if 'sku' in d['platform']:
        bigipSku = d['platform']['sku'] if 'platform' in d else ''

      if 'elaPlatform' in d:
        if d['elaPlatform'] != '':
          deviceJSON['elaPlatform'] = d['elaPlatform']

          if bigipSN != '':
            if bigipSN not in vCMPHostModules and bigipSku == 'F5-VE-VCMP':
              vCMPHostModules[bigipSN] = []

          deviceJSON['chassisSerialNumber'] = bigipSN
          deviceJSON['registrationKey'] = bigipRegKey
          deviceJSON['sku'] = bigipSku
          deviceJSON['provisionedModules'] = []

          enabledLevels = ['nominal', 'dedicated']
          for m in d['provisionedModules']:
            if m['level'] in enabledLevels:
              deviceJSON['provisionedModules'].append(m['sku'])
              if bigipSN in vCMPHostModules:
                if m['sku'] not in vCMPHostModules[bigipSN]:
                  vCMPHostModules[bigipSN].append(m['sku'])

          swOnHwJSON.append(deviceJSON)

  # Fill out vCMP host TMOS modules usage
  for sn in vCMPHostModules:

    for i in range(0,len(swOnHwJSON)):
      d = swOnHwJSON[i]

      if d['chassisSerialNumber'] == sn:
        if d['sku'] != 'F5-VE-VCMP':
          # Found a vCMP host, update TMOS modules SKU and fill provisionedModules using 'PLATFORMTYPE'-'MODULE'
          vCMPHostModulesRewritten = []
          skuModel = '-'.join(d['sku'].split('-')[2:])
          for j in range(0,len(vCMPHostModules[sn])):
            updatedSKU = skuModel + '-'.join(vCMPHostModules[sn][j].split(skuModel)[1:])
            vCMPHostModulesRewritten.append(updatedSKU)

          d['provisionedModules'] = vCMPHostModulesRewritten
        else:
          # Found a vCMP guest, update the SKU from VE-VCMP-XXX to PLATFORMTYPE-XXX
          vCMPGuestModulesRewritten = []
          skuModel = d['elaPlatform'].split(' ')[-1].upper()
          for j in range(0,len(vCMPHostModules[sn])):
            updatedSKU = skuModel + '-'.join(vCMPHostModules[sn][j].split(skuModel)[1:])
            vCMPGuestModulesRewritten.append(updatedSKU)

          d['provisionedModules'] = vCMPGuestModulesRewritten

  timeNow = datetime.datetime.now()
  monthAgo = timeNow - datetime.timedelta(days=30)

  wholeJSON = {}
  wholeJSON['report'] = utils.getVersionJson(reportType='Software on Hardware',dataplane='BIG-IQ')
  wholeJSON['periodStarted'] = monthAgo.strftime("%Y-%m-%dT%H:%M:%SZ")
  wholeJSON['periodEnded'] = timeNow.strftime("%Y-%m-%dT%H:%M:%SZ")
  wholeJSON['swOnHw'] = swOnHwJSON

  return wholeJSON,200


# Returns a full JSON that includes the software on hardware JSON
def bigIqFullSwOnHwjson(fullJSON=None):
  if fullJSON is None:
    fullJSON,code = bigIqInventory(mode='JSON')

  swonhw,code = bigIqSwOnHwjson(fullJSON)

  fullJSON['report'] = utils.getVersionJson(reportType='Full Software on Hardware',dataplane='BIG-IQ')
  fullJSON['swonhw'] = swonhw

  return fullJSON,200


# Returns a JSON containing defails, counter output, per-device CVE, telemetry and utility billing
def bigIqCompletejson(fullJSON=None):
  if fullJSON is None:
    fullJSON,code = bigIqInventory(mode='JSON')

  fullJSON['report'] = utils.getVersionJson(reportType='Complete',dataplane='BIG-IQ')

  swonhw,code = bigIqSwOnHwjson(fullJSON)
  cveByDevice,code = bigIqCVEbyDevicejson(fullJSON)

  # Removes CVE information from device details
  for i in range(len(fullJSON['details'])):
    del fullJSON['details'][i]['CVE']

  # Adds CVE by device
  fullJSON['CVE'] = cveByDevice

  return fullJSON,200


# Returns a JSON containing utility billing details for VEs and hardware platforms
def bigIqUtilityBillingjson(fullJSON=None):
  if fullJSON is None:
    fullJSON,code = bigIqInventory(mode='JSON')

  output = {}
  output['report'] = utils.getVersionJson(reportType='Utility billing',dataplane='BIG-IQ')
  output['periodStarted'] = fullJSON['periodStarted']
  output['periodEnded'] = fullJSON['periodEnded']
  output['utilityBilling'] = fullJSON['utilityBilling']
  output['records'] = []

  # First day of the previous month
  asOfDate = datetime.datetime.now().replace(day=1) - relativedelta(months=1)
  asOfDateStr = asOfDate.strftime("%d-%b-%Y")

  for i in range(len(fullJSON['details'])):
    details = fullJSON['details'][i]

    if 'elaPlatform' in details and details['elaPlatform'] != "":
      device = {}
      device['address'] = details['address']
      device['hostname'] = details['hostname']
      device['registrationKey'] = details['registrationKey'] if 'registrationKey' in details else ''
      device['AsofDate'] = asOfDateStr

      # Look for device SKU from BIG-IQ utility billing
      for i in range(0,len(fullJSON['utilityBilling'])):
        ubRecords = fullJSON['utilityBilling'][i]
        if 'records' in ubRecords:
          for ubRecord in ubRecords['records']:
            if ubRecord['hostname'] == device['hostname']:
              device['platformSKU'] = ubRecord['sku']

      # Select "nominal" and "dedicated" provisioned modules
      if 'provisionedModules' in details:
        nominalOrDedicatedModules = []
        for pm in details['provisionedModules']:
          if pm['level'] in ['nominal','dedicated']:
            nominalOrDedicatedModules.append(pm)

        device['provisionedModules'] = nominalOrDedicatedModules
      else:
        device['provisionedModules'] = ''

      output['records'].append(device)

  return output,200


# Builds BIG-IQ telemetry request body by entities
def _getTelemetryRequestBodyByEntities(module,metricSet,metric,timeRange,granDuration,granUnit):

  tr = {}
  tr['from'] = timeRange
  tr['to'] = "now"

  aggregations = {}
  #aggregations[metricSet+'$avg-value-per-event'] = {}
  #aggregations[metricSet+'$avg-value-per-event']['metricSet'] = metricSet
  #aggregations[metricSet+'$avg-value-per-event']['metric'] = metric
  aggregations[metricSet+'$'+metric] = {}
  aggregations[metricSet+'$'+metric]['metricSet'] = metricSet
  aggregations[metricSet+'$'+metric]['metric'] = metric

  timeGranularity = {}
  timeGranularity['duration'] = granDuration
  timeGranularity['unit'] = granUnit

  body = {}
  body['kind'] = "ap:query:stats:byEntities"
  body['module'] = module
  body['dimension'] = "hostname"
  body['timeRange'] = tr
  body['aggregations'] = aggregations
  body['timeGranularity'] = timeGranularity
  body['limit'] = 1000

  return body


# Builds BIG-IQ telemetry request body by time
def _getTelemetryRequestBodyByTime(module,metricSet,metric,timeRange,granDuration,granUnit,hostname):

  tr = {}
  tr['from'] = timeRange
  tr['to'] = "now"

  aggregations = {}
  #aggregations[metricSet+'$avg-value-per-event'] = {}
  #aggregations[metricSet+'$avg-value-per-event']['metricSet'] = metricSet
  #aggregations[metricSet+'$avg-value-per-event']['metric'] = metric
  aggregations[metricSet+'$'+metric] = {}
  aggregations[metricSet+'$'+metric]['metricSet'] = metricSet
  aggregations[metricSet+'$'+metric]['metric'] = metric

  timeGranularity = {}
  timeGranularity['duration'] = granDuration
  timeGranularity['unit'] = granUnit

  dimensionFilter = {}
  dimensionFilter['type'] = "eq"
  dimensionFilter['dimension'] = "hostname"
  dimensionFilter['value'] = hostname

  body = {}
  body['kind'] = "ap:query:stats:byTime"
  body['module'] = module
  body['dimension'] = "hostname"
  body['timeRange'] = tr
  body['aggregations'] = aggregations
  body['timeGranularity'] = timeGranularity
  body['dimensionFilter'] = dimensionFilter
  body['limit'] = 1000

  return body


# Returns TMOS instances telemetry
# https://clouddocs.f5.com/products/big-iq/mgmt-api/v8.0.0/ApiReferences/bigiq_public_api_ref/r_analytics_entities.html
def bigIqTelemetry(mode):
  telemetryURI = "/mgmt/ap/query/v1/tenants/default/products/device/metric-query"

  allStats = [
    { "module":"bigip-cpu","metricSet":"cpu-usage","metric":"avg-value-per-event","timeRange":"-1H","granDuration":5,"granUnit":"MINUTES" },
    { "module":"bigip-cpu","metricSet":"cpu-usage","metric":"avg-value-per-event","timeRange":"-1W","granDuration":3,"granUnit":"HOURS" },
    { "module":"bigip-cpu","metricSet":"cpu-usage","metric":"avg-value-per-event","timeRange":"-30D","granDuration":12,"granUnit":"HOURS" },
    { "module":"bigip-memory","metricSet":"free-ram","metric":"avg-value-per-event","timeRange":"-1H","granDuration":5,"granUnit":"MINUTES" },
    { "module":"bigip-memory","metricSet":"free-ram","metric":"avg-value-per-event","timeRange":"-1W","granDuration":3,"granUnit":"HOURS" },
    { "module":"bigip-memory","metricSet":"free-ram","metric":"avg-value-per-event","timeRange":"-30D","granDuration":12,"granUnit":"HOURS" },
    { "module":"bigip-disk-usage","metricSet":"disk-available-size","metric":"avg-value-per-event","timeRange":"-1H","granDuration":5,"granUnit":"MINUTES" },
    { "module":"bigip-disk-usage","metricSet":"disk-available-size","metric":"avg-value-per-event","timeRange":"-1W","granDuration":3,"granUnit":"HOURS" },
    { "module":"bigip-disk-usage","metricSet":"disk-available-size","metric":"avg-value-per-event","timeRange":"-30D","granDuration":12,"granUnit":"HOURS" },
    { "module":"bigip-traffic-summary","metricSet":"server-connections","metric":"avg-value-per-sec","timeRange":"-1H","granDuration":5,"granUnit":"MINUTES" },
    { "module":"bigip-traffic-summary","metricSet":"server-connections","metric":"avg-value-per-sec","timeRange":"-1W","granDuration":3,"granUnit":"HOURS" },
    { "module":"bigip-traffic-summary","metricSet":"server-connections","metric":"avg-value-per-sec","timeRange":"-30D","granDuration":12,"granUnit":"HOURS" },
    { "module":"bigip-traffic-summary","metricSet":"client-bytes-in","metric":"avg-value-per-sec","timeRange":"-1H","granDuration":5,"granUnit":"MINUTES" },
    { "module":"bigip-traffic-summary","metricSet":"client-bytes-in","metric":"avg-value-per-sec","timeRange":"-1W","granDuration":3,"granUnit":"HOURS" },
    { "module":"bigip-traffic-summary","metricSet":"client-bytes-in","metric":"avg-value-per-sec","timeRange":"-30D","granDuration":12,"granUnit":"HOURS" },
    { "module":"bigip-traffic-summary","metricSet":"client-bytes-out","metric":"avg-value-per-sec","timeRange":"-1H","granDuration":5,"granUnit":"MINUTES" },
    { "module":"bigip-traffic-summary","metricSet":"client-bytes-out","metric":"avg-value-per-sec","timeRange":"-1W","granDuration":3,"granUnit":"HOURS" },
    { "module":"bigip-traffic-summary","metricSet":"client-bytes-out","metric":"avg-value-per-sec","timeRange":"-30D","granDuration":12,"granUnit":"HOURS" },
    { "module":"bigip-traffic-summary","metricSet":"server-bytes-in","metric":"avg-value-per-sec","timeRange":"-1H","granDuration":5,"granUnit":"MINUTES" },
    { "module":"bigip-traffic-summary","metricSet":"server-bytes-in","metric":"avg-value-per-sec","timeRange":"-1W","granDuration":3,"granUnit":"HOURS" },
    { "module":"bigip-traffic-summary","metricSet":"server-bytes-in","metric":"avg-value-per-sec","timeRange":"-30D","granDuration":12,"granUnit":"HOURS" },
    { "module":"bigip-traffic-summary","metricSet":"server-bytes-out","metric":"avg-value-per-sec","timeRange":"-1H","granDuration":5,"granUnit":"MINUTES" },
    { "module":"bigip-traffic-summary","metricSet":"server-bytes-out","metric":"avg-value-per-sec","timeRange":"-1W","granDuration":3,"granUnit":"HOURS" },
    { "module":"bigip-traffic-summary","metricSet":"server-bytes-out","metric":"avg-value-per-sec","timeRange":"-30D","granDuration":12,"granUnit":"HOURS" }
  ]

  telemetryBody={}

  for stat in allStats:
    res,body = bigIQcallRESTURI(method = "POST", uri = telemetryURI, body = _getTelemetryRequestBodyByEntities(module=stat['module'],metricSet=stat['metricSet'],metric=stat['metric'],timeRange=stat['timeRange'],granDuration=stat['granDuration'],granUnit=stat['granUnit']) )

    if res == 200 and "result" in body:
      for r in body['result']['result']: 
        telHostname = r['hostname']
        telTimeRange = stat['timeRange']
        telVarName = stat['metricSet']
        telVarValue = r[stat['metricSet']+'$'+stat['metric']]

        if telHostname not in telemetryBody:
          telemetryBody[telHostname] = {}

        if telVarName not in telemetryBody[telHostname]:
          telemetryBody[telHostname][telVarName] = {}

        # Telemetry overall average
        telemetryBody[telHostname][telVarName][telTimeRange] = {}
        telemetryBody[telHostname][telVarName][telTimeRange]['aggregate'] = telVarValue
        telemetryBody[telHostname][telVarName][telTimeRange]['datapoints'] = []

        # Telemetry datapoints
        res,bodyDataPoints = bigIQcallRESTURI(method = "POST", uri = telemetryURI, body = _getTelemetryRequestBodyByTime(module=stat['module'],metricSet=stat['metricSet'],metric=stat['metric'],timeRange=stat['timeRange'],granDuration=stat['granDuration'],granUnit=stat['granUnit'],hostname=telHostname) )
        if res == 200:
          for dp in bodyDataPoints['result']['result']:
            datapoint = {}
            datapoint['ts'] = dp['timeMillis']//1000 if 'timeMillis' in dp else 0
            datapoint['value'] = dp[stat['metricSet']+'$'+stat['metric']]

            telemetryBody[telHostname][telVarName][telTimeRange]['datapoints'].append(datapoint)

  if mode == 'PROMETHEUS' or mode == 'PUSHGATEWAY':
    output = '# HELP bigip_tmos_telemetry TMOS Telemetry\n# TYPE bigip_tmos_telemetry gauge\n' if (mode == 'PROMETHEUS') else ''

    for host in telemetryBody:
      for stat in telemetryBody[host]:
        for timespan in telemetryBody[host][stat]:
          for datapoint in telemetryBody[host][stat][timespan]['datapoints']:
            output += 'bigip_tmos_telemetry{dataplane_type="BIG-IQ",dataplane_url="'+bigiq_fqdn+'",hostname="'+host+'",stat="'+stat+'",timespan="'+timespan+'"} '+str(datapoint['value'])+' '+str(datapoint['ts']*1000)+'\n'

    return output
  else:
    return telemetryBody


# Collect utility billing report
def bigIQCollectUtilityBilling():
  utilityBillingReport=[]

  res,allLicenses = bigIQGetLicenses()
  if res != 200:
    return utilityBillingReport

  if 'items' not in allLicenses:
    return utilityBillingReport

  # Utility billing report generation for all licenses
  for i in allLicenses['items']:
    report = {}
    regKey = i['regKey']

    # Default report in case of errors
    report['poolRegkey'] = regKey

    # Utility billing report generation request
    res,reportRequest = bigIQCreateBillingReport(regKey)

    if res == 202:
      retries = 3

      while retries > 0:
        retries -= 1
        reportId = reportRequest['selfLink'].split("/")[-1]
        time.sleep(2)

        # Report availability check
        res,r = bigIQCheckBillingReport(reportId)

        if res == 200:
          if r['status'] == "FINISHED" or r['status'] == "FAILED":
            if 'reportUri' in r:
              reportFile = r['reportUri'].split("/")[-1]
              res,theReport = bigIQFetchBillingReport(reportFile)
            else:
              res = 404

            retries = 0

            if res == 200:
              report = theReport

    # Utility billing report appended
    utilityBillingReport.append(report)

  return utilityBillingReport
