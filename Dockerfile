FROM progrium/busybox
MAINTAINER SequenceIQ

RUN opkg-install curl bash git git-http tar coreutils-base64

# download consul, plugn and jq binaries
RUN curl -Lk https://s3-eu-west-1.amazonaws.com/sequenceiq/plugn-wrap.tar.gz | tar -zxv -C /bin
RUN curl -o /usr/bin/jq http://stedolan.github.io/jq/download/linux64/jq && chmod +x /usr/bin/jq
RUN curl -Lko /bin/docker https://get.docker.io/builds/Linux/x86_64/docker-1.4.1 && chmod +x /bin/docker
RUN curl -Lko /tmp/consul.zip https://dl.bintray.com/mitchellh/consul/0.5.0_linux_amd64.zip && unzip -d /bin /tmp/consul.zip && chmod +x /bin/consul && rm /tmp/consul.zip

ENV PLUGIN_PATH /plugins
WORKDIR /tmp

# initialize a new plugn path and install default plugins
RUN plugn init
RUN plugn install https://github.com/sequenceiq/consul-plugins-install.git install
RUN plugn enable install
RUN plugn install https://github.com/sequenceiq/consul-plugins-ambari-start-stop.git ambari-start-stop
RUN plugn enable ambari-start-stop
RUN plugn install https://github.com/sequenceiq/consul-plugins-kerberos create-kdc
RUN plugn enable create-kdc

RUN mkdir /var/log/consul-watch
COPY consul-event-handler.sh /consul-event-handler.sh
COPY start.sh /start.sh
COPY dockerexec.sh /dockerexec.sh

ENTRYPOINT ["/start.sh"]
