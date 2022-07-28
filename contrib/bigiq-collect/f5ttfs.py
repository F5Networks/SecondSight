#!/usr/bin/python3

import os
import sys
import shutil
import tempfile
import tarfile
from flask import Flask, jsonify, abort, make_response, request

this = sys.modules[__name__]

jsonDir = ''

def unTarGz(file):
  global jsonDir

  # Work directory
  if jsonDir.startswith('/tmp/SecondSight_'):
    print(f"Removing {jsonDir}")
    shutil.rmtree(jsonDir,ignore_errors=False)

  jsonDir = tempfile.mkdtemp(prefix='SecondSight_',suffix='')
  print(f"Setting work directory to {jsonDir}")

  print(f"Decompressing {file}")
  tgzfile = tarfile.open(file)
  tgzfile.extractall(jsonDir)
  tgzfile.close()

  # Removes tgz filename only if POSTed, no removal if passed through the commandline
  if len(sys.argv) == 1:
    print(f"Removing {file}")
    os.remove(file)

  for c, tmpDir in enumerate(os.listdir(jsonDir+"/tmp/")):
    tgzDir = jsonDir+"/tmp/"+tmpDir
    for i, filename in enumerate(os.listdir(tgzDir)):
      os.rename(f"{tgzDir}/{filename}", f"{jsonDir}/{filename}")


if len(sys.argv) == 2:
  # tgz filename passed from commandline, untar
  unTarGz(sys.argv[1])


app = Flask(__name__)


#
# Handled calls (all GETs)
#
# https://bigiq.f5.ff.lan/mgmt/shared/resolver/device-groups/cm-bigip-allBigIpDevices/devices
# https://bigiq.f5.ff.lan/mgmt/cm/shared/current-config/sys/provision
# https://bigiq.f5.ff.lan/mgmt/cm/device/tasks/device-inventory
#
# https://bigiq.f5.ff.lan/mgmt/cm/device/reports/device-inventory/ffe12ff2-e44e-4401-908f-d02e817ceab0/results
#
# per device:
# https://bigiq.f5.ff.lan/mgmt/cm/system/machineid-resolver/aabcaca7-6986-4d0b-b9fe-b72e3473144e
#

def getFileContent(filename,retCode=200):
  json=''

  try:
    with open(jsonDir+"/"+filename,"r") as f:
      lines = f.readlines()

    for line in lines:
      json+=line
  except FileNotFoundError:
    print('Error:',filename,'not found')
    retCode=404

  return make_response(json,retCode)


@app.route('/mgmt/shared/resolver/device-groups/cm-bigip-allBigIpDevices/devices', methods=['GET'])
def getDevices():
  return getFileContent("1.bigIQCollect.json")

@app.route('/mgmt/cm/shared/current-config/sys/provision', methods=['GET'])
def getSysProvisioning():
  return getFileContent("2.bigIQCollect.json")

@app.route('/mgmt/cm/device/tasks/device-inventory', methods=['GET'])
def getDeviceInventory():
  return getFileContent("3.bigIQCollect.json")

@app.route('/mgmt/cm/device/reports/device-inventory/<string:inventoryId>/results', methods=['GET'])
def getDeviceInventoryResults(inventoryId):
  return getFileContent("4.bigIQCollect.json")

@app.route('/mgmt/cm/system/machineid-resolver/<string:machineId>', methods=['GET'])
def getMachineIdResolver(machineId):
  return getFileContent("machineid-resolver-"+machineId+".json")

@app.route('/mgmt/cm/device/licensing/pool/utility/licenses', methods=['GET'])
def getBillingLicenses():
  return getFileContent("utilitybilling-licenses.json")

@app.route('/mgmt/cm/device/tasks/licensing/utility-billing-reports', methods=['POST'])
def postsCreateBillingReport():
  return getFileContent("utilitybilling-createreport-"+request.json['regKey']+".json",retCode=202)

@app.route('/mgmt/cm/device/tasks/licensing/utility-billing-reports/<string:reportId>', methods=['GET'])
def getCheckBillingReport(reportId):
  return getFileContent("utilitybilling-reportstatus-"+reportId+".json")

@app.route('/mgmt/cm/device/licensing/license-reports-download/<string:reportFile>', methods=['GET'])
def getDownloadBillingReport(reportFile):
  return getFileContent("utilitybilling-billingreport-"+reportFile)


@app.route('/mgmt/ap/query/v1/tenants/default/products/device/metric-query', methods=['POST'])
def getDeviceMetric():
  content = request.get_json(silent=True)

  filename=""

  if "dimensionFilter" in content:
    # Returning ap:query:stats:byTime telemetry datapoints
    metricSet=""
    for m in content['aggregations'].keys():
      moduleAndMetric=m;

    filename="telemetry-datapoints-"+content['dimensionFilter']['value']+"-"+content['module']+"-"+content['aggregations'][moduleAndMetric]['metricSet']+"-"+content['timeRange']['from']+".json"
  else:
    # Returning ap:query:stats:byEntities telemetry
    metricSet=""
    for m in content['aggregations'].keys():
      moduleAndMetric=m;
    filename="telemetry-"+content['module']+"-"+content['aggregations'][moduleAndMetric]['metricSet']+"-"+content['timeRange']['from']+".json"

  return getFileContent(filename)

@app.route('/mgmt/shared/authn/login', methods=['POST'])
def bigiqLogin():
  return jsonify({
    "username": "admin",
    "loginReference": {
        "link": "https://localhost/mgmt/cm/system/authn/providers/local/login"
    },
    "loginProviderName": "local",
    "token": {
        "token": "eyJraWQiOiI4MTAwMTM3Yi1lYjY4LTQ2ZjAtODFlNi01MTBiOTFiYjVlODAiLCJhbGciOiJSUzM4NCJ9.eyJpc3MiOiJCSUctSVEiLCJqdGkiOiJQQlpkTzlwUXBsN3drRllyb2FtejZRIiwic3ViIjoiYWRtaW4iLCJhdWQiOiIxOTIuMTY4LjEuMTgiLCJpYXQiOjE2MzY3NDI1NTksImV4cCI6MTYzNjc0Mjg1OSwidXNlck5hbWUiOiJhZG1pbiIsImF1dGhQcm92aWRlck5hbWUiOiJsb2NhbCIsInVzZXIiOiJodHRwczovL2xvY2FsaG9zdC9tZ210L3NoYXJlZC9hdXRoei91c2Vycy9hZG1pbiIsInR5cGUiOiJBQ0NFU1MiLCJ0aW1lb3V0IjozMDAsImdyb3VwUmVmZXJlbmNlcyI6W119.bdlbhoHHtJ0hzdsuZRJ-WwbBpsWsk3swerV-eT8mTWXYTv2_MtWAtgOq0bZ7f0L07PO7LnLnXGwC7jy4VMR9iBAhBS-YeIVbbYwDqquDCgTfzUJbGpqqA9VhUElXSM-Bao7flpG0Mnjk_WvrMdOL9tzPmmWbrW7dHDwL9UK88BGQSUPDRZYkBcTnjFYqferY7zRRW3moNyyz_wuoSx9rrquT2xwFEypPcO4yXSR7kUPneRSHnqqJ-J-qnyVef57sH_C0jwAap9fJhkx83_JB3DgVkel5xBbtrDp79g2iXeL8lw3D2X6B2YzrkkhrjTr6BQDJBYYP-zpABNsZXqZoWlnBVPytcC_g8rp3bgLSAJrYWP9ghAjerHtR6Rmmwm3-zSdM7LYIjPGtzdSMrQSXXC37_3AHdaF5FvLnGNHSsfh7MH9TAdI12mqt8qgCK76HWndiHbSEpkirLWBgTix1EA0OZPaws9rosGR6E8qYA703FwJc-DQgrxneBZZdzwLd",
        "userName": "admin",
        "authProviderName": "local",
        "user": {
            "link": "https://localhost/mgmt/shared/authz/users/admin"
        },
        "groupReferences": [],
        "timeout": 300,
        "address": "192.168.1.18",
        "type": "ACCESS",
        "jti": "PBZdO9pQpl7wkFYroamz6Q",
        "exp": 1636742859,
        "iat": 1636742559,
        "generation": 15,
        "lastUpdateMicros": 1636742559279067,
        "kind": "shared:authz:tokens:authtokenitemstate",
        "selfLink": "https://localhost/mgmt/shared/authz/tokens/eyJraWQiOiI4MTAwMTM3Yi1lYjY4LTQ2ZjAtODFlNi01MTBiOTFiYjVlODAiLCJhbGciOiJSUzM4NCJ9.eyJpc3MiOiJCSUctSVEiLCJqdGkiOiJQQlpkTzlwUXBsN3drRllyb2FtejZRIiwic3ViIjoiYWRtaW4iLCJhdWQiOiIxOTIuMTY4LjEuMTgiLCJpYXQiOjE2MzY3NDI1NTksImV4cCI6MTYzNjc0Mjg1OSwidXNlck5hbWUiOiJhZG1pbiIsImF1dGhQcm92aWRlck5hbWUiOiJsb2NhbCIsInVzZXIiOiJodHRwczovL2xvY2FsaG9zdC9tZ210L3NoYXJlZC9hdXRoei91c2Vycy9hZG1pbiIsInR5cGUiOiJBQ0NFU1MiLCJ0aW1lb3V0IjozMDAsImdyb3VwUmVmZXJlbmNlcyI6W119.bdlbhoHHtJ0hzdsuZRJ-WwbBpsWsk3swerV-eT8mTWXYTv2_MtWAtgOq0bZ7f0L07PO7LnLnXGwC7jy4VMR9iBAhBS-YeIVbbYwDqquDCgTfzUJbGpqqA9VhUElXSM-Bao7flpG0Mnjk_WvrMdOL9tzPmmWbrW7dHDwL9UK88BGQSUPDRZYkBcTnjFYqferY7zRRW3moNyyz_wuoSx9rrquT2xwFEypPcO4yXSR7kUPneRSHnqqJ-J-qnyVef57sH_C0jwAap9fJhkx83_JB3DgVkel5xBbtrDp79g2iXeL8lw3D2X6B2YzrkkhrjTr6BQDJBYYP-zpABNsZXqZoWlnBVPytcC_g8rp3bgLSAJrYWP9ghAjerHtR6Rmmwm3-zSdM7LYIjPGtzdSMrQSXXC37_3AHdaF5FvLnGNHSsfh7MH9TAdI12mqt8qgCK76HWndiHbSEpkirLWBgTix1EA0OZPaws9rosGR6E8qYA703FwJc-DQgrxneBZZdzwLd"
    },
    "refreshToken": {
        "token": "eyJraWQiOiI4MTAwMTM3Yi1lYjY4LTQ2ZjAtODFlNi01MTBiOTFiYjVlODAiLCJhbGciOiJSUzM4NCJ9.eyJpc3MiOiJCSUctSVEiLCJqdGkiOiI3ZGdxd0wyUy1YaVdxVUFOMFJQTmFRIiwic3ViIjoiYWRtaW4iLCJhdWQiOiIxOTIuMTY4LjEuMTgiLCJpYXQiOjE2MzY3NDI1NTksImV4cCI6MTYzNjc3ODU1OSwidXNlck5hbWUiOiJhZG1pbiIsImF1dGhQcm92aWRlck5hbWUiOiJsb2NhbCIsInVzZXIiOiJodHRwczovL2xvY2FsaG9zdC9tZ210L3NoYXJlZC9hdXRoei91c2Vycy9hZG1pbiIsInR5cGUiOiJSRUZSRVNIIiwidGltZW91dCI6MzYwMDAsImdyb3VwUmVmZXJlbmNlcyI6W119.GmuZ0Sauq8I_z9VrFkM0MqoE3EoBI1brZqfVHhZj8_NWxxVAy3yM_sfaWphYtKCag0ZERj8k0S9xzQyPW-Prz4rSGCdfkplIOZ902zk1B1oDxY8Vyc91si4hp_mB_wRlrdbF1u5JIe0yyAPP2l9L9sOmmuMXV8zYXzLVdIYWZr0SLeuLh82QyjyKujClyWnTbCGGWK50bE6HmMq1Zur8UDZl-kccpUW14PYzag11rcIynHpdJk-8zViL7UqYhCTluKEkIwwQKfS0QxjhRKJmyJk4Co_I2MgIVej9BKhvzMQ_Z3_9Ln3h7sAs44p_rTx8bi2wWACExBhg5OKQxQWFirWahd8_VVWv5tCGv7bmiiFxwc78o0cH5PNxc5tFs-NdNLCwOydWFMBHTQY-gv9GZkKVvocIKs0e_8UX-MiB_PMUQHVaFtRFZDpEYrvyGS749BbQzFyWP-MIhl6TKZlwqdSw-bbtQe0SotVFDapoZ9fj4BwdVAreoVNqbokIGGzk",
        "userName": "admin",
        "authProviderName": "local",
        "user": {
            "link": "https://localhost/mgmt/shared/authz/users/admin"
        },
        "groupReferences": [],
        "timeout": 36000,
        "address": "192.168.1.18",
        "type": "REFRESH",
        "jti": "7dgqwL2S-XiWqUAN0RPNaQ",
        "exp": 1636778559,
        "iat": 1636742559,
        "generation": 16,
        "lastUpdateMicros": 1636742559283013,
        "kind": "shared:authz:tokens:authtokenitemstate",
        "selfLink": "https://localhost/mgmt/shared/authz/tokens/eyJraWQiOiI4MTAwMTM3Yi1lYjY4LTQ2ZjAtODFlNi01MTBiOTFiYjVlODAiLCJhbGciOiJSUzM4NCJ9.eyJpc3MiOiJCSUctSVEiLCJqdGkiOiI3ZGdxd0wyUy1YaVdxVUFOMFJQTmFRIiwic3ViIjoiYWRtaW4iLCJhdWQiOiIxOTIuMTY4LjEuMTgiLCJpYXQiOjE2MzY3NDI1NTksImV4cCI6MTYzNjc3ODU1OSwidXNlck5hbWUiOiJhZG1pbiIsImF1dGhQcm92aWRlck5hbWUiOiJsb2NhbCIsInVzZXIiOiJodHRwczovL2xvY2FsaG9zdC9tZ210L3NoYXJlZC9hdXRoei91c2Vycy9hZG1pbiIsInR5cGUiOiJSRUZSRVNIIiwidGltZW91dCI6MzYwMDAsImdyb3VwUmVmZXJlbmNlcyI6W119.GmuZ0Sauq8I_z9VrFkM0MqoE3EoBI1brZqfVHhZj8_NWxxVAy3yM_sfaWphYtKCag0ZERj8k0S9xzQyPW-Prz4rSGCdfkplIOZ902zk1B1oDxY8Vyc91si4hp_mB_wRlrdbF1u5JIe0yyAPP2l9L9sOmmuMXV8zYXzLVdIYWZr0SLeuLh82QyjyKujClyWnTbCGGWK50bE6HmMq1Zur8UDZl-kccpUW14PYzag11rcIynHpdJk-8zViL7UqYhCTluKEkIwwQKfS0QxjhRKJmyJk4Co_I2MgIVej9BKhvzMQ_Z3_9Ln3h7sAs44p_rTx8bi2wWACExBhg5OKQxQWFirWahd8_VVWv5tCGv7bmiiFxwc78o0cH5PNxc5tFs-NdNLCwOydWFMBHTQY-gv9GZkKVvocIKs0e_8UX-MiB_PMUQHVaFtRFZDpEYrvyGS749BbQzFyWP-MIhl6TKZlwqdSw-bbtQe0SotVFDapoZ9fj4BwdVAreoVNqbokIGGzk"
    },
    "generation": 8,
    "lastUpdateMicros": 1636742559283127
});

@app.route('/upload', methods = ['POST'])
def upload_file():
   if request.method == 'POST':
      f = request.files['file']
      print(f"Uploading file {f.filename}")
      dstFilename = '/tmp/SecondSightData.tgz'
      f.save(dstFilename)
      unTarGz(dstFilename)

      return make_response(jsonify({'status': 'file uploaded successfully'}), 200)

@app.errorhandler(404)
def not_found(error):
    return make_response(jsonify({'error': 'Not found'}), 404)

if __name__ == '__main__':
  app.run(host='0.0.0.0',port=5001)
