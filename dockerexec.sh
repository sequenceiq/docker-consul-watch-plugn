#!/bin/bash

execInContainer() {
  set -x
  declare desc="Executes a scriptfile in the given container. Usage: execute targetcontainer script"
  declare targetContainer=$1
  declare scriptfile=$2
  : ${targetContainer:? required}
  : ${scriptfile:? required}
  docker exec -i $targetContainer \
    bash -c 'scriptfile=/tmp/$RANDOM.sh; \
      umask 022; \
      while read -r line; do echo "$line" >> $scriptfile; done; \
      chmod +x $scriptfile; \
      PAYLOAD='"\"$PAYLOAD\""' \
      EVENT_ID='"\"$EVENT_ID\""' \
      EVENT_LTIME='"\"$EVENT_LTIME\""' \
      EVENT_VERSION='"\"$EVENT_VERSION\""' \
      CONSUL_HOST='"\"$CONSUL_HOST\""' \
      CONSUL_HTTP_PORT='"\"$CONSUL_HTTP_PORT\""' \
      LOGFILE='"\"$LOGFILE\""' \
      $scriptfile' \
      < $scriptfile
}

main() {
  execInContainer "$DOCKER_CONTAINER" "$SCRIPT_FILE"
}

debug(){
  [[ "$DEBUG" ]] && echo "[DEBUG] $(date) $*"
}

[[ "$0" == "$BASH_SOURCE" ]] && main "$@"
