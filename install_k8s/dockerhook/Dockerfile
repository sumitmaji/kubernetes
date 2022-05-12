FROM ubuntu:focal

LABEL sum.label-schema.vcs-url="https://github.com/sumitmaji/dockerhook.git"

RUN apt-get update && apt-get install -y net-tools apt-utils ca-certificates software-properties-common

RUN apt-get update && apt-get install -y apt-transport-https \
&& apt-get install -y curl wget \
&& curl -sL https://deb.nodesource.com/setup_14.x | bash - \
&& apt-get install -y docker.io \
&& curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
&& apt-get install -y \
nodejs \
git \
socat \
build-essential \
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#Install Docker

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

EXPOSE 5002

CMD [ "npm", "start" ]
