#!/bin/bash

service_has_related_services() {
  local service="$1"; shift
  local units="$@"
  local base_service="$(echo "$service" | sed "s/@.*$//")"
  local instance="$(echo "$service" | sed "s/.*@//")"
  filtered_units=( $(filter_units "$units" | grep "$base_service" ) )
  for unit in "${filtered_units[@]}"; do
    if [[ "$unit" =~ .*sidekick.* ]]; then
      return 0
    fi
  done
  echo "Missing sidekick on ${base_service}@${instance}"
}

process_service() {
  local service="$1"; shift
  local units="$@"
  local error_message="$(service_has_related_services "$service" "$units")"
  if [ "$error_message" != "" ]; then
    echo "$error_message"
  fi
  return 0
}

filter_units() {
  local units=( $@ )
  for unit in "${units[@]}"; do
    echo "$unit"
  done
}

list_units() {
  local units="$(fleetctl list-units | tail -n +2 | awk '{print $1}' | grep 'octoblu' | grep '@')"
  echo "${units[@]}"
}

fatal() {
  local message="$1"
  echo "$message"
  exit 1
}

usage(){
  echo 'USAGE: octoblu-list-invalid-services'
  echo ''
  echo '- List all invalid services'
  echo '  example: octoblu-list-invalid-services'
  echo ''
  echo '- List all services matching the search term'
  echo '  example: octoblu-list-invalid-services | grep meshblu'
  echo ''
}

script_directory(){
  local source="${BASH_SOURCE[0]}"
  local dir=""

  while [ -h "$source" ]; do # resolve $source until the file is no longer a symlink
    dir="$( cd -P "$( dirname "$source" )" && pwd )"
    source="$(readlink "$source")"
    [[ $source != /* ]] && source="$dir/$source" # if $source was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  done

  dir="$( cd -P "$( dirname "$source" )" && pwd )"
  echo "$dir"
}

version(){
  local directory="$(script_directory)"
  local version=$(cat "$directory/VERSION")

  echo "$version"
  exit 0
}

main(){
  local cmd="$1"

  if [ "$cmd" == '--help' -o "$cmd" == '-h' ]; then
    usage
    exit 0
  fi

  if [ "$cmd" == '--version' -o "$cmd" == '-v' ]; then
    version
    exit 0
  fi

  local units="$(list_units)"
  local services=( $(filter_units "$units" | grep -v 'sidekick@' | grep -v 'register@' ) )
  if [ "$?" != "0" ]; then
    fatal 'unable to list units'
  fi
  for service in "${services[@]}"; do
    process_service "$service" "${units[@]}" || fatal 'unable to process service'
  done
}

main "$@"
