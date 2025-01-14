import datetime;

def getVersionJson(reportType='',dataplane='',tarfileInfo=''):
  output = {}
  output['type'] = 'Second Sight'
  output['dataplane'] = dataplane
  output['kind'] = reportType
  output['version'] = '4.0'
  output['timestamp'] = str(datetime.datetime.now())

  output['tarfile'] = tarfileInfo

  return output
