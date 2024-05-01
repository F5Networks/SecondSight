#!/usr/bin/python3

"""
Second Sight Gateway
"""

import sys
import os
import toml
import smtplib
import ssl

import time
import uvicorn
import json

import paho.mqtt.client as mqtt
import ssl
import socket
import requests

from datetime import datetime as dt

from typing import Any, Dict, AnyStr, List, Union

from fastapi import FastAPI, Request, File, UploadFile
from fastapi.responses import PlainTextResponse, Response, JSONResponse


# Configuration singleton
class ssgConfig(object):
    _instance = None
    config = {}

    def __new__(cls,configFile):
        if cls._instance is None:
            print(f'{dt.now()} Reading configuration from {configFile}')
            cls._instance = super(cls, ssgConfig).__new__(cls)

            with open(configFile) as cfgFile:
                cls.config = toml.load(cfgFile)

        return cls._instance


cfg = ssgConfig(configFile="./gateway.conf")

app = FastAPI(
    title=cfg.config['main']['banner'],
    version=cfg.config['main']['version'],
    contact={"name": "GitHub", "url": cfg.config['main']['url']}
)

JSONObject = Dict[AnyStr, Any]
JSONArray = List[Any]
JSONStructure = Union[JSONArray, JSONObject]


#
# Logging
#
def logger(m:str):
    print(f"{dt.now()} [{cfg.config['main']['id']} {cfg.config['main']['version']}] {m}")


#
# MQTT publisher
#
def mqtt_publish(msg: bytearray):
    if cfg.config['mqtt']['enabled'] == False:
        return 200, {"status": 204, "message":"disabled"}

    logger(f"MQTT: Connecting to broker {cfg.config['mqtt']['host']}:{cfg.config['mqtt']['port']}")

    if cfg.config['mqtt']['version'] == 3:
        mqttClient = mqtt.Client(callback_api_version = mqtt.CallbackAPIVersion.VERSION2, client_id = socket.gethostname(),
            protocol = mqtt.MQTTv311, clean_session = True)
    elif cfg.config['mqtt']['version'] == 5:
        mqttClient = mqtt.Client(callback_api_version = mqtt.CallbackAPIVersion.VERSION2, client_id = socket.gethostname(),
            protocol=mqtt.MQTTv5)
    else:
        logger(f"MQTT: Invalid version {cfg.config['mqtt']['version']}, must be either 3 or 5")
        quit()

    # Callback functions
    mqttClient.on_connect = mqtt_callback_on_connect
    mqttClient.on_message = mqtt_callback_on_message
    #mqttClient.on_subscribe = mqtt_callback_on_subscribe
    #mqttClient.on_unsubscribe = mqtt_callback_on_unsubscribe

    # Authentication
    authType = cfg.config['mqtt']['auth_type'].lower()
    if authType == 'password':
        mqttClient.username_pw_set(username = cfg.config['mqtt']['username'], password = cfg.config['mqtt']['password'])
    elif authType == 'tls':
        mqttClient.tls_set(certfile = './client.crt', keyfile = './client.key', ca_certs = './server-ca.crt', cert_reqs = ssl.CERT_REQUIRED)
    else:
        logger(f"MQTT: Invalid auth_type {authType}, must be either 'password' or 'tls'")
        quit()

    # Connection
    mqttClient.connect(host = cfg.config['mqtt']['host'], port = cfg.config['mqtt']['port'], keepalive = 60,
        bind_address = "", bind_port = 0, properties = None)

    mqttClient.loop_start()

    time.sleep(1)

    if mqttClient.is_connected():
        # Publish message
        logger(f"MQTT: Publishing to {cfg.config['mqtt']['pub_topic']} with QoS {cfg.config['mqtt']['qos']}")
        mqttClient.publish(cfg.config['mqtt']['pub_topic'], msg, qos = cfg.config['mqtt']['qos'])
        retVal = 200, {"status": 200, "message": "success"}
    else:
        # Broker not connected
        logger(f"MQTT: Publish failed")
        retVal = 422, {"status": 422, "message": "broker not connected"}

    mqttClient.loop_stop()

    return retVal


def mqtt_callback_on_connect(client, userdata, flags, reason_code, properties=None):
    if reason_code == 0:
        logger(f"MQTT: Connection successful")
        client.subscribe(topic = cfg.config['mqtt']['sub_topic'])
    else:
        logger(f"MQTT: Connection failed, {reason_code}")


def mqtt_callback_on_message(client, userdata, message, properties=None):
    logger(f"MQTT: Received message {message.payload} on topic '{message.topic}' with QoS {message.qos}")


def mqtt_callback_on_subscribe(client, userdata, mid, qos, properties=None):
    logger(f"MQTT: Subscribed with QoS {qos} {mid} {userdata}")


def mqtt_callback_on_unsubscribe(client, userdata, mid, qos, properties=None):
    logger(f"MQTT: Unsubscribed with QoS {qos}")


#
# HTTP publisher
#
def http_publish(msg: bytearray):
    if cfg.config['http']['enabled'] == False:
        return 200, {"status": 204, "message":"disabled"}

    authType = cfg.config['http']['auth_type'].lower()

    mTLS_cert = None
    basic_auth = None

    if authType == 'basic':
        # Basic authentication
        basic_auth = (cfg.config['http']['username'], cfg.config['http']['password'])
    elif authType == 'tls':
        # mTLS authentication
        mTLS_cert = (cfg.config['http']['tls_client_cert'], cfg.config['http']['tls_client_key'])
    else:
        return 422, {"status": 422, "message": f"invalid auth_type '{authType}'"}

    multipart_form_data = {
        'file': ('tarball.zip', msg)
    }

    # Publish to F5 telemetry endpoint
    logger(f"HTTP: POSTing to {cfg.config['http']['url']}")

    try:
        r = requests.post(url = cfg.config['http']['url'],
            files = multipart_form_data,
            auth = basic_auth,
            verify = False,
            cert = mTLS_cert
            )

        if r.status_code == 200:
            # HTTP POST successful
            logger(f"HTTP: Successfully POSTed to {cfg.config['http']['url']} return code is {r.status_code}")
            output = 200, {"status": 200, "message": "success"}
        else:
            # HTTP POST failed
            logger(f"HTTP: POST to {cfg.config['http']['url']} failed with return code {r.status_code}")
            output = r.status_code, {"status": r.status_code, "message": "failed"}

    except requests.exceptions.RequestException as e:
        output = 500, {"status": 500, "message": "Failed with code {r.status_code}"}

    return output


#
# SMTP publisher
#
def smtp_publish(msg: bytearray):
    if cfg.config['smtp']['enabled'] == False:
        return 200, {"status": 204, "message":"disabled"}

    connType = cfg.config['smtp']['type']
    validConnType = True

    logger(f"SMTP: Sending through {cfg.config['smtp']['host']}:{cfg.config['smtp']['port']} using {connType}")

    if connType == 'ssl':
        # Create a secure SSL context
        context = ssl.create_default_context()

        try:
            with smtplib.SMTP_SSL(cfg.config['smtp']['host'], cfg.config['smtp']['port'], context=context) as server:
                server.login(cfg.config['smtp']['username'], cfg.config['smtp']['password'])

            output = 200, {"status": 200, "message": "success"}
        except Exception as e:
            logger(f"SMTP: Error {e}")
            output = 500, {"status": 500, "message": e}

    elif connType == 'starttls':
        try:
            with smtplib.SMTP(cfg.config['smtp']['host'], cfg.config['smtp']['port']) as server:
                server.ehlo()
                server.starttls
                server.login(cfg.config['smtp']['username'], cfg.config['smtp']['password'])

            output = 200, {"status": 200, "message": "success"}
        except Exception as e:
            logger(f"SMTP: Error {e}")
            output = 500, {"status": 500, "message": e}
    else:
        output = 422, {"status": 422, "message": f"invalid type '{connType}'"}
        validConnType = False

    if validConnType:
        pass

    return output

#
# Payload is the BIG-IQ tarball
# curl 127.0.0.1:5000/api/v1/archive -X POST -F "file=@/path/filename.ext"
#
@app.post("/api/v1/archive", status_code=200, response_class=JSONResponse)
async def v1_post_archive(response: Response, file: UploadFile = File(...)):
    data = file.file.read()

    logger(f"Received: File \"{file.filename}\" size {file.size} type {file.headers['content-type']}")

    # Publish to MQTT endpoint
    mqtt_code, mqtt_output = mqtt_publish(data)
    http_code, http_output = http_publish(data)
    smtp_code, smtp_output = smtp_publish(data)

    output = {}
    output['mqtt'] = mqtt_output
    output['http'] = http_output
    output['smtp'] = smtp_output

    if mqtt_code != 200 or http_code != 200 or smtp_code != 200:
        response.status_code = 422
    else:
        response.status_code = 200

    return output


if __name__ == '__main__':
    logger(f"{cfg.config['main']['banner']} {cfg.config['main']['version']} - {cfg.config['main']['url']}")

    logger(f"MQTT: Enabled, broker is {cfg.config['mqtt']['host']}:{cfg.config['mqtt']['port']}" if cfg.config['mqtt']['enabled'] else "MQTT: Disabled")
    logger(f"HTTP: Enabled, endpoint is {cfg.config['http']['url']}" if cfg.config['http']['enabled'] else "HTTP: Disabled")
    logger(f"SMTP: Enabled, server is {cfg.config['smtp']['host']}:{cfg.config['smtp']['port']}" if cfg.config['smtp']['enabled'] else "SMTP: Disabled")

    uvicorn.run("gateway:app", host = cfg.config['main']['address'], port = cfg.config['main']['port'], access_log = cfg.config['main']['access_log'])
