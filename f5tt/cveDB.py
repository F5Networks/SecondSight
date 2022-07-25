import os
import sys
import ssl
import json
import requests
import time
import urllib3.exceptions
from requests import Request, Session
from requests import ReadTimeout, ConnectTimeout, HTTPError, Timeout, ConnectionError
from requests.packages.urllib3.exceptions import InsecureRequestWarning

requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

this = sys.modules[__name__]

# Global variables
this.nistURL='https://services.nvd.nist.gov'
this.nistApiKey=''
this.proxy={}

# Local nist responses cache
this.cveCachedDB={}

# TMOS modules vs NIST product names for cpeMatchString
tmosModules2NIST={
  'afm': ['big-ip_advanced_firewall_manager','big-ip_afm'],
  'dos': ['big-ip_ddos_hybrid_defender'],
  'asm': ['big-ip_application_security_manager','big-ip_advanced_web_application_firewall','big-ip_asm'],
  'ltm': ['big-ip_local_traffic_manager','big-ip_ltm'],
  'avr': ['big-ip_application_visibility_and_reporting'],
  'sslo': ['big-ip_ssl_orchestrator','ssl_orchestrator'],
  'cgnat': ['big-ip_carrier-grade_nat'],
  'ilx': [],
  'lc': ['big-ip_link_controller'],
  'swg': [],
  'gtm': ['big-ip_global_traffic_manager','big-ip_dns'],
  'apm': ['big-ip_access_policy_manager','big-ip_access_policy_manager_client','access_policy_manager_clients','big-ip_apm'],
  'pem': ['big-ip_policy_enforcement_manager','big-ip_pem'],
  'fps': ['big-ip_fraud_protection_service','big-ip_websafe','websafe','f5_websafe'],
  'urldb': []
}

# Module initialization
def init(nistURL='https://services.nvd.nist.gov',nistApiKey='',proxy={}):
  this.nistURL=nistURL
  this.nistApiKey=nistApiKey
  this.proxy=proxy


# Returns the cpeMatchString to query NIST REST API
def __mkCpeMatchString(vendor="*",product="*",version="*"):
  return 'cpe:2.3:*:'+vendor+':'+product+':'+version


# Fetches all CVE for the given vendor/product/version
def __getFromNist(vendor,product="*",version="*"):
  cpeMatchString=__mkCpeMatchString(vendor,product,version)

  if cpeMatchString not in this.cveCachedDB:
    # If we don't have a local cached copy of the JSON, fetch it from NIST and cache it to speed up lookup
    headers = { 'Content-Type': 'application/json' }

    if this.nistApiKey == '':
      params = {
        'resultsPerPage': 2000,
        'cpeMatchString': cpeMatchString
      }
    else:
      params = {
        'resultsPerPage': 2000,
        'cpeMatchString': cpeMatchString,
        'apiKey': this.nistApiKey
      }

    s = Session()
    req = Request('GET',this.nistURL+"/rest/json/cves/1.0",params=params,headers=headers)

    p = s.prepare_request(req)
    s.proxies = proxy
    try:
      res = s.send(p,verify=False)
      if res.status_code == 200:
        this.cveCachedDB[cpeMatchString]=res.json()
    except (ConnectTimeout, HTTPError, ReadTimeout, Timeout, ConnectionError):
        this.cveCachedDB[cpeMatchString]={}

  return this.cveCachedDB[cpeMatchString]


# Returns all CVE for the given F5 TMOS product/version
def getF5(product="*",version="*"):
  matchingCVE={}

  try:
    allCVE = __getFromNist(vendor="f5",product="*",version=version)
  except:
    return matchingCVE

  if product in tmosModules2NIST:
    matchingProducts=tmosModules2NIST[product]

    for product in matchingProducts:
      if 'result' in allCVE:
        for cve in allCVE['result']['CVE_Items']:
          allCPEMatches=cve['configurations']['nodes'][0]['cpe_match']

          for cpeMatch in allCPEMatches:
            if product in cpeMatch['cpe23Uri']:
              # Found CVE match
              cveId=cve['cve']['CVE_data_meta']['ID']
              cveUrl=cve['cve']['references']['reference_data'][0]['url']
              cveDesc=cve['cve']['description']['description_data'][0]['value']
              cveBaseSeverity=cve['impact']['baseMetricV3']['cvssV3']['baseSeverity']
              cveBaseScore=cve['impact']['baseMetricV3']['cvssV3']['baseScore']
              cveExplScore=cve['impact']['baseMetricV2']['exploitabilityScore']

              if cveId not in matchingCVE:
                matchingCVE[cveId]={"id":cveId,"url":cveUrl,"description":cveDesc,"baseSeverity":cveBaseSeverity,"baseScore":cveBaseScore,"exploitabilityScore":cveExplScore}

  return matchingCVE


# Returns all CVE for the given NGINX instance version
def getNGINX(version="*"):
  allCVE = __getFromNist(vendor="f5",product="nginx",version=version)
  matchingCVE={}

  if version != '':
    for cve in allCVE['result']['CVE_Items']:
      allCPEMatches=cve['configurations']['nodes'][0]['cpe_match']

      for cpeMatch in allCPEMatches:
        # Found CVE match
        cveId=cve['cve']['CVE_data_meta']['ID']
        cveUrl=cve['cve']['references']['reference_data'][0]['url']
        cveDesc=cve['cve']['description']['description_data'][0]['value']
        cveBaseSeverity=cve['impact']['baseMetricV3']['cvssV3']['baseSeverity'] if 'baseMetricV3' in cve['impact'] else ''
        cveBaseScore=cve['impact']['baseMetricV3']['cvssV3']['baseScore'] if 'baseMetricV3' in cve['impact'] else ''
        cveExplScore=cve['impact']['baseMetricV2']['exploitabilityScore'] if 'baseMetricV2' in cve['impact'] else ''

        if cveId not in matchingCVE:
          matchingCVE[cveId]={"id":cveId,"url":cveUrl,"description":cveDesc,"baseSeverity":cveBaseSeverity,"baseScore":cveBaseScore,"exploitabilityScore":cveExplScore}

    cveF5 = getF5(product="nginx",version=version)

    matchingCVE.update(cveF5)

  return matchingCVE
