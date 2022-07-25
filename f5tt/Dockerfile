FROM ubuntu:latest
RUN apt-get update

RUN apt-get install -y -q build-essential python3-pip python3-dev python3-simplejson git nano curl
RUN pip3 install --upgrade virtualenv

RUN mkdir deployment
RUN virtualenv /deployment/env/
RUN /deployment/env/bin/python -m pip install --upgrade pip
RUN /deployment/env/bin/pip3 install fastapi uvicorn requests jinja2 json2html clickhouse-driver

WORKDIR /deployment
COPY app.py .
COPY nms.py .
COPY bigiq.py .
COPY cveDB.py .
COPY f5ttCH.py .
COPY utils.py .

CMD env/bin/python3 app.py
