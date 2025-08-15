FROM ubuntu:trusty
MAINTAINER Sumit Kumar Maji

RUN apt-get update \
	&& LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -y --force-yes --no-install-recommends \
	openssh-server \
	openssh-client \
	net-tools \
	iputils-ping \
	curl \
	python \
	wget \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir -p /container/scripts
ADD ./scripts/* /container/scripts/
RUN /container/scripts/setup.sh

VOLUME ["/usr/local/repository"]
