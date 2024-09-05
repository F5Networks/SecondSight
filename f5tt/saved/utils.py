import datetime;

def getVersionJson(reportType='',dataplane=''):
  output = {}
  output['type'] = 'Second Sight'
  output['dataplane'] = dataplane
  output['kind'] = reportType
  output['version'] = '4.0'
  output['timestamp'] = str(datetime.datetime.now())

  return output
