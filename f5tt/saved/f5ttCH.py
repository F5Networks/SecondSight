import os
import sys
import datetime
from clickhouse_driver import Client as ClickHouse

this = sys.modules[__name__]

this.ch_host=''
this.ch_port=0
this.ch_user=''
this.ch_pass=''
this.ch=''

# Initialization
def init(ch_host, ch_port, ch_user, ch_pass):
  this.ch_host=ch_host
  this.ch_port=ch_port
  this.ch_user=ch_user
  this.ch_pass=ch_pass

  print('Initializing ClickHouse [',this.ch_host,':',this.ch_port,']')
  try:
    connect()
    execute('create database if not exists f5tt')
    execute(' \
      create table if not exists f5tt.tracking (\
        `ts` DateTime CODEC(DoubleDelta), \
        `data` LowCardinality(String) \
      ) \
      ENGINE = MergeTree() \
      order by ts \
    ')
    close()
  except:
    e = sys.exc_info()[0]
    print(datetime.datetime.now(),"Clickhouse init failed",e)

  return True


# ClickHouse connection
def connect():
  try:
    this.ch = ClickHouse.from_url('clickhouse://'+this.ch_user+':'+this.ch_pass+'@'+this.ch_host+':'+this.ch_port)
  except:
    e = sys.exc_info()[0]
    print(datetime.datetime.now(),"Clickhouse connect failed",e)
    this.ch = ''

# ClickHouse disconnection
def close():
  try:
    this.ch.disconnect()
  except:
    e = sys.exc_info()[0]
    print(datetime.datetime.now(),"Clickhouse close failed",e)

  this.ch=''

# ClickHouse query
def execute(query):
  if this.ch != '':
    try:
      output = this.ch.execute(query);
      return output
    except:
      e = sys.exc_info()[0]
      print(datetime.datetime.now(),"Clickhouse query failed",e)

  return None
