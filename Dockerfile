# I'd like to use alpine, but for some reason, DynamoDB Local seems to hang
# in all the alpine java images.
FROM openjdk:8-jre

LABEL maintainer="Zach Wily <zach@instructure.com>"
LABEL maintainer="Levin Calado <levincalado@gmail.com>"

# We need java and node in this image, so we'll start with java (cause it's
# more hairy), and then dump in the node Dockerfile below. It'd be nice if there
# was a more elegant way to compose at the image level, but I suspect the
# response here would be "use two containers".

################################################################################
## START COPY FROM https://github.com/nodejs/docker-node
################################################################################
##
## Released under MIT License
## Copyright (c) 2015 Joyent, Inc.
## Copyright (c) 2015 Node.js contributors
##

ENV NPM_CONFIG_LOGLEVEL info
ENV NODE_VERSION 8.16.0

RUN curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz" \
  && curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && tar -xJf "node-v$NODE_VERSION-linux-x64.tar.xz" -C /usr/local --strip-components=1 \
  && rm "node-v$NODE_VERSION-linux-x64.tar.xz"

################################################################################
## END COPY
################################################################################

RUN apt-get update && \
    apt-get install -y git supervisor nginx && \
    apt-get clean && \
    rm -fr /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN npm install -g dynamodb-admin --ignore-scripts

RUN cd /usr/local/lib/node_modules/dynamodb-admin && \
    npm install --allow-root

RUN cd /usr/lib && \
    curl -L https://s3-us-west-2.amazonaws.com/dynamodb-local/dynamodb_local_latest.tar.gz | tar xz
RUN mkdir -p /var/lib/dynamodb
VOLUME /var/lib/dynamodb

COPY nginx-proxy.conf /etc/nginx-proxy.conf
COPY supervisord.conf /etc/supervisord.conf
COPY .htpasswd /etc/nginx/.htpasswd
RUN mkdir -p /var/log/supervisord

# Configuration for dynamo-admin to know where to hit dynamo.
ENV DYNAMO_ENDPOINT http://localhost:8000/
ENV AWS_ACCESS_KEY_ID accessKey
ENV AWS_SECRET_ACCESS_KEY secret

# For dinghy users.
ENV VIRTUAL_HOST dynamo.docker
ENV VIRTUAL_PORT 8000

# Main proxy on 9000, dynamo-admin on 80/80, dynamodb on 8000
EXPOSE 8000 8080 9000

ENV DYNAMODB_LOCAL_ARGS "-dbPath /var/lib/dynamodb"

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf", "-e", "debug"]
