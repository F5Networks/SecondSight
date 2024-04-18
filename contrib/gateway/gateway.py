#!/usr/bin/python3

"""
Second Sight Gateway
"""

import uvicorn
import json
import uuid

import paho.mqtt.client as mqtt
import ssl
import socket

from datetime import datetime as dt

from typing import Any, Dict, AnyStr, List, Union

from fastapi import FastAPI, Request, File, UploadFile
from fastapi.responses import PlainTextResponse, Response, JSONResponse

# Configuration
import ssgConfig

cfg = ssgConfig.ssgConfig(configFile="./gateway.conf")

if cfg.config['telemetry']['version'] == 3:
    telemetryClient = mqtt.Client(callback_api_version = mqtt.CallbackAPIVersion.VERSION2, client_id = socket.gethostname(),
        protocol = mqtt.MQTTv311, clean_session = True)
elif cfg.config['telemetry']['version'] == 5:
    telemetryClient = mqtt.Client(callback_api_version = mqtt.CallbackAPIVersion.VERSION2, client_id = socket.gethostname(),
        protocol=mqtt.MQTTv5)
else:
    print(f"Invalid telemetry version {cfg.config['telemetry']['version']}, must be either 3 or 5")
    quit()


app = FastAPI(
    title="Second Sight Gateway",
    version="1.0.0",
    contact={"name": "GitHub", "url": "https://github.com/f5Networks/Secondsight"}
)

JSONObject = Dict[AnyStr, Any]
JSONArray = List[Any]
JSONStructure = Union[JSONArray, JSONObject]


def callback_on_connect(client, userdata, flags, reason_code, properties=None):
    client.subscribe(topic = cfg.config['channels']['reply'])

def callback_on_message(client, userdata, message, properties=None):
    print(
        f"{dt.now()} telemetry: Received message {message.payload} on topic '{message.topic}' with QoS {message.qos}"
    )

def callback_on_subscribe(client, userdata, mid, qos, properties=None):
    print(f"{dt.now()} telemetry: Subscribed with QoS {qos}")

def callback_on_unsubscribe(client, userdata, mid, qos, properties=None):
    print(f"{dt.now()} telemetry: Unsubscribed with QoS {qos}")


def telemetry_connect():
    print("Initializing telemetry")

    # Callback functions
    telemetryClient.on_connect = callback_on_connect
    telemetryClient.on_message = callback_on_message
    telemetryClient.on_subscribe = callback_on_subscribe
    telemetryClient.on_unsubscribe = callback_on_unsubscribe

    # Authentication
    telemetryClient.username_pw_set(username = cfg.config['telemetry']['username'], password = cfg.config['telemetry']['password'])
    #telemetryClient.tls_set(ca_certs = "cert.pem")

    # Connection
    telemetryClient.connect(host = cfg.config['telemetry']['host'], port = cfg.config['telemetry']['port'], keepalive = 60,
        bind_address = "", bind_port = 0, properties = None)
    telemetryClient.loop_start()


#
# Payload is the BIG-IQ tarball
# curl 127.0.0.1:5000/api/v1/archive -X POST -F "file=@/path/filename.ext"
#
@app.post("/api/v1/archive", status_code=200, response_class=JSONResponse)
async def v1_post_archive(file: UploadFile = File(...)):
    # Reset the file pointer to the beginning
    file.file.seek(0)

    # mTLS authentication
    #mTLS_cert = ('/path/client.crt', '/path/client.key')

    multipart_form_data = {
        'tarball': ('tarball.zip', file.file)
    }

    # Publish to F5 telemetry endpoint
    r = requests.post(url = endpoint,
                      files = multipart_form_data,
                      auth = ('admin','default'),
                      verify = False,
                      #cert = mTLS_cert
                      )

    print(f"Response HTTP status: {r.status_code}")
    print(f"Response Body       : {r.content.decode('utf-8')}")

    output = json.loads(r.content.decode('utf-8'))
    output['filename'] = file.filename

    return output

if __name__ == '__main__':
    print(f"{cfg.config['main']['banner']} {cfg.config['main']['version']} - {cfg.config['main']['url']}")

    telemetry_connect()

    msg_info = telemetryClient.publish("secondsight/archives", '{"type": "BIG-IQ"}', qos=0)
    print(msg_info)

    uvicorn.run("gateway:app", host='0.0.0.0', port=5000)
