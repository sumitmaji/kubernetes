FROM ubuntu:focal

LABEL sum.label-schema.vcs-url="https://github.com/sumitmaji/reghook.git"

RUN apt-get update && apt-get install -y net-tools apt-utils ca-certificates software-properties-common

RUN apt-get update && apt-get install -y apt-transport-https \
&& apt-get install -y curl wget \
&& curl -sL https://deb.nodesource.com/setup_14.x | bash - \
&& curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
&& apt-get install -y \
nodejs \
git \
socat \
build-essential \
&& apt-get clean

RUN echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
RUN apt-get update
#Kubernets version 1.24.0 is working properly, downgrading to 1.23.0
RUN apt-get install -qy kubectl=1.23.0-00 --allow-downgrades

#Installing helm
RUN curl https://baltocdn.com/helm/signing.asc | apt-key add - \
&& apt-get install apt-transport-https --yes \
&& echo "deb https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list \
&& apt-get update \
&& apt-get install helm \
&& helm version --short \
&& helm repo add stable https://charts.helm.sh/stable

RUN node -v

# Create app directory
WORKDIR /usr/src/app

# Install app dependencies
# A wildcard is used to ensure both package.json AND package-lock.json are copied
# where available (npm@5+)
COPY server/package*.json ./

RUN npm install
# If you are building your code for production
# RUN npm install --only=production

COPY server/index.js .


RUN mkdir -p scripts
ADD scripts/build.sh scripts/build.sh
ADD scripts/config scripts/config
RUN chmod +x scripts/build.sh
ADD rbac.yaml scripts/rbac.yaml
ADD setup.sh scripts/setup.sh
RUN chmod +x scripts/setup.sh

EXPOSE 5003

ENTRYPOINT [ "./scripts/setup.sh" ]