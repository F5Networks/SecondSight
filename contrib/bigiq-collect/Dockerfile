FROM ubuntu:latest

ENV TZ=Europe/Rome
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update

RUN apt-get install -y -q build-essential python3-pip python3-dev python3-simplejson nano curl python3-flask
RUN pip3 install --upgrade virtualenv

RUN mkdir deployment
RUN virtualenv /deployment/env/
RUN /deployment/env/bin/python -m pip install --upgrade pip
RUN /deployment/env/bin/pip3 install flask requests

WORKDIR /deployment
COPY f5ttfs.py .

CMD python3 f5ttfs.py
