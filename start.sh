#!/bin/bash

: ${BRIDGE_IP:="172.17.42.1"}
: ${CONSUL_HTTP_PORT:="8500"}

[[ "TRACE" ]] && set -x

debug() {
  [[ "DEBUG" ]]  && echo "[DEBUG] $@" 1>&2
}

fix-nameserver() {
  cat>/etc/resolv.conf<<EOF
nameserver $BRIDGE_IP
search service.consul node.consul
EOF
}

set-server-ip() {
  while [ -z "$(dig_ambari)" ]; do
    sleep 1
    echo -n .
  done
  sed -i "s/^hostname=.*/hostname=$(dig_ambari)/" \
    /etc/ambari-agent/conf/ambari-agent.ini
}

start-watch() {
  consul watch --http-addr=$BRIDGE_IP:$CONSUL_HTTP_PORT --type=event /consul-event-handler.sh 2> /tmp/consul_handler_errors.log &
}


main() {
  fix-nameserver
  set-server-ip
  start-watch
  /etc/init.d/sshd start
}

main "$@"
