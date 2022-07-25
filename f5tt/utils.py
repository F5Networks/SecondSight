def getVersionJson(reportType='',dataplane=''):
  output = {}
  output['type'] = 'Second Sight'
  output['dataplane'] = dataplane
  output['kind'] = reportType
  output['version'] = '4.0'

  return output
