#!/bin/bash

: ${LOGFILE:=/tmp/consul_handler.log}
: ${BRIDGE_IP:=127.0.0.1}
: ${CONSUL_HTTP_PORT:=8500}
: ${DEBUG:=1}

[[ "TRACE" ]] && set -x

debug(){
  [[ "$DEBUG" ]] && echo "[DEBUG] $*" >> $LOGFILE
}

get_field() {
  declare json="$1"
  declare field="$2"

  echo "$json"|jq ".$field" -r
}

__envVars() {
  declare eventId=$1
  declare ltime=$2
  declare version=$3

  echo "EVENT_ID=$eventId \
    EVENT_LTIME=$ltime \
    EVENT_VERSION=$version \
    CONSUL_HOST=$BRIDGE_IP \
    CONSUL_HTTP_PORT=$CONSUL_HTTP_PORT \
    LOGFILE=$LOGFILE"
}

__executeScript() {
  declare envVars=$1
  declare eventSpecPayload=$2
  declare scriptFile=$(echo $eventSpecPayload | cut -d" " -f 1)

  debug "execute $scriptFile..."
  eval $envVars \
    PAYLOAD=\"$(echo $eventSpecPayload  | cut -d" " -f 2-)\" \
    $scriptFile
}

__downloadAndExecuteScript() {
  declare envVars=$1
  declare eventSpecPayload=$2
  declare url=$(echo $eventSpecPayload | cut -d" " -f 1)
  declare scriptfile="/tmp/consulevent-$RANDOM.sh"

  debug "execute script from $url url locally..."
  curl -Lko $scriptfile $url
  chmod +x $scripfile

  debug "execute downloaded script $scriptFile..."
  eval $envVars \
    PAYLOAD=\"$(echo $eventSpecPayload  | cut -d" " -f 2-)\" \
    $scriptFile
}

__executeScriptInContainer() {
  declare envVars=$1
  declare eventSpecPayload=$2
  declare dockerContainer=$(echo $eventSpecPayload | cut -d" " -f 1)
  declare scriptFile=$(echo $eventSpecPayload | cut -d" " -f 2)

  debug "execute the $scriptFile script in $dockerContainer container"
  eval $envVars \
    PAYLOAD=\"$(echo $eventSpecPayload  | cut -d" " -f 3-)\" \
    DOCKER_CONTAINER=$dockerContainer \
    SCRIPT_FILE=$scriptFile \
    /dockerexec.sh
}

__triggerPlugin() {
  declare envVars=$1
  declare eventSpecPayload=$2

  debug "trigger plugins with $event hook..."
  eval $envVars \
    PAYLOAD=\"$eventSpecPayload\" \
    plugn trigger $event
}

__triggerPluginInContainer() {
  declare envVars=$1
  declare eventSpecPayload=$2
  declare dockerContainer=$(echo $(docker inspect --format="{{.Name}}" $(docker ps -qa)|grep $(echo $eventSpecPayload | cut -d" " -f 1))|sed 's,/,,')

  eval $envVars \
    PAYLOAD=\"$(echo $eventSpecPayload | cut -d" " -f 2-)\" \
    WRAPPER_SCRIPT=/dockerexec.sh \
    DOCKER_CONTAINER=$dockerContainer \
    plugn trigger $event
}

__getHostName() {
  while : ; do
    hostname=$(hostname).node.dc1.consul
    [[ $? == 0 ]] && break
    [[ $? != 0 ]] && sleep 5
  done
  echo $hostname
}

process_json() {
  while read json; do
    debug $json

    event=$(get_field $json Name)
    id=$(get_field $json ID)
    payload=$(get_field $json Payload | base64 -d)
    ltime=$(get_field $json LTime)
    version=$(get_field $json Version)
    eventtype=$(echo $payload | cut -d" " -f 1)
    eventSpecPayload=$(echo $payload | cut -d" " -f 2-)
    cmdEnvVars=$(__envVars $id $ltime $version)

    debug "event=$event, id=$id, payload=$payload, eventtype=$eventtype, specPayload=$eventSpecPayload"
    if [[ -z $id ]]; then
      debug "eventid is missing, skip processing"
      continue
    fi
    curl -X PUT -d 'ACCEPTED' "http://$BRIDGE_IP:$CONSUL_HTTP_PORT/v1/kv/events/$id/$(__getHostName)"

    case "$eventtype" in
      EXEC)
        __executeScript "$cmdEnvVars" "$eventSpecPayload" ;;
      DOWNLOAD_AND_EXEC)
        __downloadAndExecuteScript "$cmdEnvVars" "$eventSpecPayload" ;;
      EXEC_IN_CONTAINER)
        __executeScriptInContainer "$cmdEnvVars" "$eventSpecPayload" ;;
      TRIGGER_PLUGN)
        __triggerPlugin "$cmdEnvVars" "$eventSpecPayload" ;;
      TRIGGER_PLUGN_IN_CONTAINER)
        __triggerPluginInContainer "$cmdEnvVars" "$eventSpecPayload" ;;
    esac

    if [ $? -eq 0 ]; then
      debug "$eventtype finished successfully"
      curl -X PUT -d 'FINISHED' "http://$BRIDGE_IP:$CONSUL_HTTP_PORT/v1/kv/events/$id/$(__getHostName)"
    else
      debug "$eventtype failed to finish successfully"
      curl -X PUT -d 'FAILED' "http://$BRIDGE_IP:$CONSUL_HTTP_PORT/v1/kv/events/$id/$(__getHostName)"
    fi
  done
}

main() {
  while read array; do
    [[ -n $array ]] && echo $array | jq .[] -c | process_json
  done
}

[[ "$0" == "$BASH_SOURCE" ]] && main "$@"
