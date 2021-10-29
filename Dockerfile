# why ubuntu:groovy and not node:alpine?
# cause alpine in docker don't play good with ipv6
# and apk will hang when its fetch returns dual-stack.
FROM ubuntu:20.04
LABEL maintainer="https://github.com/elgeeko1"

EXPOSE 3000

USER root

ARG TIMEZONE=America/Los_Angeles
ENV LIRC_WEB_APP_PATH=/opt/lirc-web
ENV LIRC_WEB_NODE_PATH=${LIRC_WEB_APP_PATH}/node_modules/lirc_web
ENV CONTAINER_USER=lirc_web

RUN mkdir -p ${LIRC_WEB_APP_PATH}
WORKDIR ${LIRC_WEB_APP_PATH}

# Preconfigure debconf for non-interactive installation - otherwise complains about terminal
# Avoid ERROR: invoke-rc.d: policy-rc.d denied execution of start.
ARG DEBIAN_FRONTEND=noninteractive
ENV DISPLAY localhost:0.0
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
	&& dpkg-divert --local --rename --add /sbin/initctl \
	&& ln -sf /bin/true /sbin/initctl \
	&& echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d

# set timezone (for interactive environments)
# tzdata will be installed by node.js dependencies,
# so just configure the timezone now
RUN echo "${TIMEZONE}" > /etc/timezone

# install prerequisites: lirc, node, npm
# install patch to apply patchfile
# install curl for docker healthcheck
RUN apt-get update -q \
  && apt-get -q -y install --upgrade --no-install-recommends lirc nodejs npm patch curl \
  && apt-get -q -y clean \
  && rm -rf /var/lib/apt/lists/*

# install lirc_web
RUN npm install --prefix ${LIRC_WEB_APP_PATH} lirc_web

# copy default configuration file to lirc-web
COPY app/config.json ${LIRC_WEB_NODE_PATH}

# apply lirc_web patch to resolve empty remote commands due to a race condition
COPY app/lirc_node.js.diff .
RUN  patch ${LIRC_WEB_APP_PATH}/node_modules/lirc_node/lib/lirc_node.js lirc_node.js.diff

# create a user with a random UID to run lirc-web
# which provides some level of security to prevent the container user from
# accessing the host filesystem
RUN adduser --disabled-password --gecos "" --uid `shuf -i 2000-60000 -n 1` ${CONTAINER_USER}
USER ${CONTAINER_USER}

ENTRYPOINT ${LIRC_WEB_NODE_PATH}/app.js

# verify the server is running at the expected port
HEALTHCHECK --interval=1m --timeout=1s --start-period=5s \
   CMD curl -f http://localhost:3000 || exit 1
