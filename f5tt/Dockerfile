FROM ubuntu:20.04

ENV TZ=Europe/Rome
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
        apt-get install -y -q build-essential python3-pip python3-dev python3-simplejson git nano curl && \
        pip3 install fastapi uvicorn requests requests-cache clickhouse-driver python-dateutil && \
        # f5ttfs.py
        pip3 install flask && \
        mkdir deployment

WORKDIR /deployment

COPY f5ttfs.py .
COPY app.py .
COPY nms.py .
COPY bigiq.py .
COPY cveDB.py .
COPY f5ttCH.py .
COPY utils.py .
COPY startup.sh .

RUN chmod +x startup.sh

CMD ./startup.sh
