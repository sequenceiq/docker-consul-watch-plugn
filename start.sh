#!/bin/bash

: ${BRIDGE_IP:="172.17.42.1"}
: ${CONSUL_HTTP_PORT:="8500"}
: ${CONSUL_RPC_PORT:="8400"}

[[ "TRACE" ]] && set -x

debug() {
  [[ "DEBUG" ]]  && echo "[DEBUG] $@" 1>&2
}

# --dns isn't available for: docker run --net=host
# sed -i /etc/resolf.conf fails:
# sed: cannot rename /etc/sedU9oCRy: Device or resource busy
# here comes the tempfile workaround ...
fix-nameserver() {
  cat>/etc/resolv.conf<<EOF
nameserver $BRIDGE_IP
search service.consul node.consul
EOF
}

wait-for-consul() {
  while : ; do
    consul members --rpc-addr=$BRIDGE_IP:$CONSUL_RPC_PORT
    [[ $? == 0 ]] && break
    [[ $? != 0 ]] && sleep 5
  done
}

start-watch() {
  ln -sf /lib/libpthread-2.18.so /lib/libpthread.so.0
  wait-for-consul
  consul watch --http-addr=$BRIDGE_IP:$CONSUL_HTTP_PORT --type=event /consul-event-handler.sh 2>> /var/log/consul-watch/consul_handler_errors.log &
  sleep 5
  ln -sf /lib/libpthread-0.9.33.2.so  /lib/libpthread.so.0
}

main() {
  fix-nameserver
  start-watch >> /tmp/startup.log 2>&1
  echo NOTHING TO DO>> /tmp/tmp.log
  while true; do
    sleep 3
    tail -f /tmp/tmp.log
  done
}

[[ "$0" == "$BASH_SOURCE" ]] && main "$@"
