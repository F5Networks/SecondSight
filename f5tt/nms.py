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
from requests import Request, Session
from requests.packages.urllib3.exceptions import InsecureRequestWarning
from email.message import EmailMessage

import cveDB
import f5ttCH
import utils

this = sys.modules[__name__]

requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

this.nms_fqdn=''
this.nms_username=''
this.nms_password=''
this.nms_proxy={}
this.nms_auth_type=''
this.nms_auth_token=''

# Module initialization
def init(fqdn,username,password,auth_type,auth_token,nistApiKey,proxy,ch_host,ch_port,ch_user,ch_pass,sample_interval):
  this.nms_fqdn=fqdn
  this.nms_username=username
  this.nms_password=password
  this.nms_proxy=proxy
  this.nms_auth_type=auth_type.lower()
  this.nms_auth_token=auth_token

  print('Initializing NMS [',this.nms_fqdn,']')

  cveDB.init(nistApiKey = nistApiKey,proxy=proxy)

  f5ttCH.init(ch_host,ch_port,ch_user,ch_pass)
  t=threading.Thread(target=pollingThread,args=(sample_interval,))
  t.start()


# Periodic sample thread running every 'sample_interval' minutes
def pollingThread(sample_interval):
  print('Starting polling thread every',sample_interval,'minutes')

  while True:
    now=datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    instancesJson,retcode = nmsInstances(mode='JSON')

    trackingJson = {}
    trackingJson['instances'] = instancesJson['instances'] if 'instances' in instancesJson else ''
    trackingJson['modules'] = instancesJson['modules'] if 'modules' in instancesJson else ''

    print(now,'Collecting instances usage',trackingJson)

    if 'instances' in instancesJson:
      query='insert into f5tt.tracking (ts,data) values (\''+str(now)+'\',\''+json.dumps(trackingJson)+'\')'

      f5ttCH.connect()
      out=f5ttCH.execute(query)
      f5ttCH.close()

    time.sleep(sample_interval)

### NGINX Management System REST API

def nmsRESTCall(method,uri):
  s = Session()
  req = ''
  if this.nms_auth_type == '' or this.nms_auth_type == 'basic':
    # Basic authentication
    req = Request(method,this.nms_fqdn+uri,auth=requests.auth.HTTPBasicAuth(this.nms_username,this.nms_password))
  elif this.nms_auth_type == 'digest':
    # Digest authentication
    req = Request(method,this.nms_fqdn+uri,auth=requests.auth.HTTPDigestAuth(this.nms_username,this.nms_password))
  elif this.nms_auth_type == 'jwt':
    # JWT-based authentication
    auth_header = {'Authorization': 'Bearer {}'.format(this.nms_auth_token)}
    req = Request(method,this.nms_fqdn+uri,headers=auth_header)

  p = s.prepare_request(req)
  s.proxies = this.nms_proxy
  res = s.send(p,verify=False)

  if res.status_code == 200:
    data = res.json()
  else:
    data = {}

  return res.status_code,data


### NGINX Management System query functions

# Returns NGINX OSS/Plus instances managed by NMS in JSON format
def nmsInstances(mode):
  # Fetching NMS license
  status,license = nmsRESTCall(method='GET',uri='/api/platform/v1/license')

  if status != 200:
    return {'error': 'fetching license failed'},status

  # Fetching NMS system information
  status,system = nmsRESTCall(method='GET',uri='/api/platform/v1/systems')

  if status != 200:
    return {'error': 'fetching systems information failed'},status

  subscriptionId=license['currentStatus']['subscription']['id']
  instanceType=license['currentStatus']['state']['currentInstance']['features'][0]['id']
  instanceVersion=license['currentStatus']['state']['currentInstance']['version']
  instanceSerial=license['currentStatus']['state']['currentInstance']['id']
  totalManaged=0

  plusManaged=0
  for i in system['items']:
    for instance in i['nginxInstances']:
      totalManaged+=1
      if instance['build']['nginxPlus'] == True:
        plusManaged+=1

  subscriptionDict = {}
  subscriptionDict['id'] = subscriptionId
  subscriptionDict['type'] = instanceType
  subscriptionDict['version'] = instanceVersion
  subscriptionDict['serial'] = instanceSerial

  output = {}
  output['report'] = utils.getVersionJson(reportType='Full',dataplane='NGINX Management Suite')
  output['subscription'] = subscriptionDict
  output['details'] = []

  onlineNginxPlus = 0
  onlineNginxOSS = 0

  for i in system['items']:
    systemId=i['uid']

    # Fetch system details
    status,systemDetails = nmsRESTCall(method='GET',uri='/api/platform/v1/systems/'+systemId+'?showDetails=true')
    if status != 200:
      return {'error': 'fetching system details failed for '+systemId},status

    for instance in i['nginxInstances']:
      # Fetch instance details
      instanceUID = instance['uid']

      status,instanceDetails = nmsRESTCall(method='GET',uri='/api/platform/v1/systems/'+systemId+'/instances/'+instanceUID)
      if status != 200:
        return {'error': 'fetching instance details failed for '+systemId+' / '+instanceUID},status

      # Fetch CVEs
      allCVE=cveDB.getNGINX(version=instanceDetails['build']['version'])

      detailsDict = {}
      detailsDict['instance_id'] = instance['uid']
      detailsDict['osInfo'] = systemDetails['osRelease']
      detailsDict['hypervisor'] = systemDetails['processor'][0]['hypervisor']
      detailsDict['type'] = "oss" if instanceDetails['build']['nginxPlus'] == False else "plus"
      detailsDict['version'] = instanceDetails['build']['version']
      detailsDict['last_seen'] = instance['status']['lastStatusReport']
      detailsDict['state'] = instance['status']['state']
      detailsDict['createtime'] = instance['startTime']
      detailsDict['modules'] = instanceDetails['loadableModules']
      detailsDict['networkconfig'] = {}
      detailsDict['networkconfig']['networkInterfaces'] = systemDetails['networkInterfaces']
      detailsDict['hostname'] = systemDetails['hostname']
      detailsDict['name'] = systemDetails['displayName']
      detailsDict['CVE'] = []
      detailsDict['CVE'].append(allCVE)

      if detailsDict['state'] == 'online':
        onlineNginxOSS = onlineNginxOSS + 1 if detailsDict['type'] == "oss" else onlineNginxOSS
        onlineNginxPlus = onlineNginxPlus + 1 if detailsDict['type'] == "plus" else onlineNginxPlus

      output['details'].append(detailsDict)

  instancesDict = {}
  instancesDict['nginx_plus'] = {}
  instancesDict['nginx_oss'] = {}
  instancesDict['nginx_plus']['managed'] = plusManaged
  instancesDict['nginx_plus']['online'] = onlineNginxPlus
  instancesDict['nginx_plus']['offline'] = plusManaged - onlineNginxPlus
  instancesDict['nginx_oss']['managed'] = int(totalManaged)-int(plusManaged)
  instancesDict['nginx_oss']['online'] = onlineNginxOSS
  instancesDict['nginx_oss']['offline'] = int(totalManaged)-int(plusManaged)-onlineNginxOSS

  output['instances'] = instancesDict

  modulesTracking = {}

  if 'details' in output:
    for d in output['details']:
      if d['state'] == 'online' and 'modules' in d:
        for m in d['modules']:
          if m in modulesTracking:
            modulesTracking[m] = modulesTracking[m] + 1
          else:
            modulesTracking[m] = 1

  output['modules'] = modulesTracking

  # NGINX time-based usage
  tbOutput, tbRetcode = nmsTimeBasedJson(-1,4)

  if tbRetcode != 200:
    output['timebased'] = {}
  else:
    output['timebased'] = tbOutput['instances']

  if mode == 'JSON':
    return output,200

  # PROMETHEUS or PUSHGATEWAY mode
  metricsOutput = ''

  # NGINX instance counting
  metricsOutput += '# HELP nginx_instances_online Online NGINX OSS instances\n' if (mode == 'PROMETHEUS') else ''
  metricsOutput += '# TYPE nginx_instances_online gauge\n' if (mode == 'PROMETHEUS') else ''
  metricsOutput += 'nginx_instances_online{subscription="'+output['subscription']['id']+'",instanceType="'+output['subscription']['type']+ \
    '",type="nginx_plus"} '+ \
    str(output['instances']['nginx_plus']['online'])+'\n'
  metricsOutput += 'nginx_instances_online{subscription="'+output['subscription']['id']+'",instanceType="'+output['subscription']['type']+ \
    '",type="nginx_oss"} '+ \
    str(output['instances']['nginx_oss']['online'])+'\n'

  metricsOutput += '# HELP nginx_instances_offline Online NGINX OSS instances\n' if (mode == 'PROMETHEUS') else ''
  metricsOutput += '# TYPE nginx_instances_offline gauge\n' if (mode == 'PROMETHEUS') else ''
  metricsOutput += 'nginx_instances_offline{subscription="'+output['subscription']['id']+'",instanceType="'+output['subscription']['type']+ \
    '",type="nginx_plus"} '+ \
    str(output['instances']['nginx_plus']['offline'])+'\n'
  metricsOutput += 'nginx_instances_offline{subscription="'+output['subscription']['id']+'",instanceType="'+output['subscription']['type']+ \
    '",type="nginx_oss"} '+ \
    str(output['instances']['nginx_oss']['offline'])+'\n'

  # CVE
  nginxRel = {}
  cves = {}
  for d in output['details']:
    if d['version'] in nginxRel:
      nginxRel[d['version']] += 1
    else:
      nginxRel[d['version']] = 1

    metricsOutput += '# HELP nginx_cve_details NGINX CVE details\n# TYPE nginx_cve_details counter\n' if (mode == 'PROMETHEUS') else ''
    for c in d['CVE'][0]:
      metricsOutput += 'nginx_cve_details{subscription="'+subscriptionId+'",instanceType="'+instanceType+ \
        '",hostname="'+d['hostname']+ \
        '",version="'+d['version']+ \
        '",type="'+d['type']+ \
        '",state="'+d['state']+ \
        '",cve="'+c+ \
        '",severity="'+str(d['CVE'][0][c]['baseSeverity'])+ \
        '",base_score="'+str(d['CVE'][0][c]['baseScore'])+ \
        '",exploitability_score="'+str(d['CVE'][0][c]['exploitabilityScore'])+ \
        '"} '+str(d['CVE'][0][c]['baseScore'])+'\n'

      if c in cves:
        cves[c] += 1
      else:
        cves[c] = 1

  # CVE totals
  metricsOutput += '# HELP nginx_cve NGINX CVE count\n# TYPE nginx_cve gauge\n' if (mode == 'PROMETHEUS') else ''
  for c in cves:
    metricsOutput += 'nginx_cve_totals{subscription="'+output['subscription']['id']+'",instanceType="'+output['subscription']['type']+ \
      '",cve="'+c+'"} '+str(cves[c])+'\n'

  # NGINX releases
  metricsOutput += '# HELP nginx_releases NGINX releases count\n# TYPE nginx_releases gauge\n' if (mode == 'PROMETHEUS') else ''
  for v in nginxRel:
    metricsOutput += 'nginx_releases{subscription="'+output['subscription']['id']+'",instanceType="'+output['subscription']['type']+ \
      '",release="'+v+'"} '+str(nginxRel[v])+'\n'

  return metricsOutput,200


# Returns the CVE-centric JSON
def nmsCVEjson():
  fullJSON,retcode = nmsInstances(mode='JSON')
  cveJSON = {}
  cveJSON['report'] = utils.getVersionJson(reportType='CVE',dataplane='NGINX Management Suite')

  for d in fullJSON['details']:
    nginxHostname = d['hostname']
    nginxVersion = d['version']

    for cve in d['CVE'][0]:
      if cve not in cveJSON:
        cveJSON[cve] = d['CVE'][0][cve]
        cveJSON[cve]['devices'] = []

      deviceJSON = {}
      deviceJSON['hostname'] = nginxHostname
      deviceJSON['version'] = nginxVersion

      cveJSON[cve]['devices'].append(deviceJSON)

  return cveJSON,200


# Returns the time-based instances usage distribution JSON
def nmsTimeBasedJson(monthStats,hourInterval):
  output = {}
  output['report'] = utils.getVersionJson(reportType='Time-based',dataplane='NGINX Management Suite')
  output['subscription'] = {}
  output['instances'] = []

  # Fetching NMS license
  status,license = nmsRESTCall(method='GET',uri='/api/platform/v1/license')

  if status == 200:
    output['subscription']['id']=license['currentStatus']['subscription']['id']
    output['subscription']['type']=license['currentStatus']['state']['currentInstance']['features'][0]['id']
    output['subscription']['version']=license['currentStatus']['state']['currentInstance']['version']
    output['subscription']['serial']=license['currentStatus']['state']['currentInstance']['id']

  # Clickhouse data aggregation
  query = " \
    SELECT \
      min(ts) as from, \
      max(ts) as to, \
      max(JSON_VALUE(data, '$.instances.nginx_oss.managed')) AS nginx_oss_managed, \
      max(JSON_VALUE(data, '$.instances.nginx_oss.online')) AS nginx_oss_online, \
      max(JSON_VALUE(data, '$.instances.nginx_oss.offline')) AS nginx_oss_offline, \
      max(JSON_VALUE(data, '$.instances.nginx_plus.managed')) AS nginx_plus_managed, \
      max(JSON_VALUE(data, '$.instances.nginx_plus.online')) AS nginx_plus_online, \
      max(JSON_VALUE(data, '$.instances.nginx_plus.offline')) AS nginx_plus_offline, \
      max(JSON_VALUE(data, '$.modules.ngx_http_app_protect_module')) AS ngx_http_app_protect_module, \
      max(JSON_VALUE(data, '$.modules.ngx_http_app_protect_dos_module')) AS ngx_http_app_protect_dos_module, \
      max(JSON_VALUE(data, '$.modules.ngx_http_js_module')) AS ngx_http_js_module, \
      max(JSON_VALUE(data, '$.modules.ngx_stream_js_module')) AS ngx_stream_js_module \
    FROM f5tt.tracking \
    WHERE ts >= (select timestamp_sub(month,"+str(-monthStats)+",toStartOfMonth(now()))) \
    AND ts < (addDays(toStartOfMonth(addMonths(now() + toIntervalMonth(1),"+str(monthStats)+")),-1)) \
    GROUP BY toStartOfInterval(toDateTime(ts), toIntervalHour("+str(hourInterval)+")) \
    ORDER BY max(ts) ASC \
  "

  f5ttCH.connect()
  out=f5ttCH.execute(query)
  f5ttCH.close()

  if out != None:
    if out != []:
      for tuple in out:
        if len(tuple) == 12:
          item = {}
          item['ts'] = {}
          item['ts']['from'] = str(tuple[0])
          item['ts']['to'] = str(tuple[1])
          item['nginx_oss'] = {}
          item['nginx_oss']['managed'] = tuple[2] if tuple[2] != "" else "0"
          item['nginx_oss']['online'] = tuple[3] if tuple[3] != "" else "0"
          item['nginx_oss']['offline'] = tuple[4] if tuple[4] != "" else "0"
          item['nginx_plus'] = {}
          item['nginx_plus']['managed'] = tuple[5] if tuple[5] != "" else "0"
          item['nginx_plus']['online'] = tuple[6] if tuple[6] != "" else "0"
          item['nginx_plus']['offline'] = tuple[7] if tuple[7] != "" else "0"
          item['modules'] = {}
          item['modules']['ngx_http_app_protect_module'] = tuple[8] if tuple[8] != "" else "0"
          item['modules']['ngx_http_app_protect_dos_module'] = tuple[9] if tuple[9] != "" else "0"
          item['modules']['ngx_http_js_module'] = tuple[10] if tuple[10] != "" else "0"
          item['modules']['ngx_stream_js_module'] = tuple[11] if tuple[11] != "" else "0"

          output['instances'].append(item)
    return output,200
  else:
    return {"message":"ClickHouse unreachable"},503
