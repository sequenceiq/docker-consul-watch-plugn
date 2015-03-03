FROM gliderlabs/alpine:3.1
MAINTAINER Sequenceiq <info@sequenceiq.com>

RUN apk-install curl bash tar git

# download consul, plugn and jq binaries
RUN curl -Lk https://s3-eu-west-1.amazonaws.com/sequenceiq/plugn.tar.gz | tar -zxv -C /bin
RUN curl -o /usr/bin/jq http://stedolan.github.io/jq/download/linux64/jq && chmod +x /usr/bin/jq

# initialize a new plugn path and install default plugins
ENV PLUGIN_PATH /plugins
RUN plugn init
RUN plugn install https://github.com/sequenceiq/consul-plugins-install.git install
RUN plugn enable install
RUN plugn install https://github.com/sequenceiq/consul-plugins-ambari-start-stop ambari-start-stop
RUN plugn enable ambari-start-stop

COPY consul-event-handler.sh /consul-event-handler.sh
VOLUME /var/log
EXPOSE 8080
CMD ["/start.sh"]
