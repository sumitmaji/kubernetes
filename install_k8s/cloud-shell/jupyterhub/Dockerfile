FROM jupyter/base-notebook:latest

USER root
RUN apt-get update && apt-get install -y wget \
    && wget https://github.com/tsl0922/ttyd/releases/download/1.7.3/ttyd.x86_64 \
    && mv ttyd.x86_64 /usr/local/bin/ttyd \
    && chmod +x /usr/local/bin/ttyd \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

USER $NB_UID