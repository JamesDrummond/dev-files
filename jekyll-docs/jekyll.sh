#!/bin/sh 
# Copyright (c) 2016 Codenvy, S.A.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#

# See: https://sipb.mit.edu/doc/safe-shell/
set -u

init_logging() {
  BLUE='\033[1;34m'
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  NC='\033[0m'
}

init_global_variables() {
    DEBUG=""
    DEBUG_UNISON=""
    # Uncomment the follow to disable debug
    DEBUG_UNISON="> /dev/null 2>&1"
    DEBUG="> /dev/null 2>&1"
    
    CHE_MINI_PRODUCT_NAME=codenvy
    
    REFERENCE_CONTAINER_COMPOSE_FILE=$(echo $(pwd)/docker-compose.yml)
    export IMAGE_NAME="che/docs:dev"
    
    DOCKER_CLEAN_OLD_COMMAND="docker rm -f \$(docker ps -aq --filter \"name=${CONTAINER_NAME}\") &&
        docker volume rm $(docker volume ls -qf dangling=true) "
    
    COPY_SSHKEY_COMMAND="docker exec ${CONTAINER_NAME} /usr/bin/entrypoint.sh && \
        docker cp ${CONTAINER_NAME}:/home/jekyll/.ssh/id_rsa ${HOME}/.ssh/jekyll_id_rsa${CONTAINER_NAME} && \
        chown -R root:root ${HOME}/.ssh/jekyll_id_rsa${CONTAINER_NAME} && chmod 600 ${HOME}/.ssh/jekyll_id_rsa${CONTAINER_NAME}"
    
    export UNISON_SYNC_PATH=${DOC_PATH}
    export UNISON_SYNC_PATH_CHE=${CHE_DOC_PATH}
    UNISON_REPEAT=""
    
    chmod u+x ${PWD}/unison
    rm -rf ${PWD}/.unison${CONTAINER_NAME}
    rm -rf ${UNISON_SYNC_PATH}/_site
    mkdir -p ${PWD}/.unison${CONTAINER_NAME} 
    cp default.prf ${PWD}/.unison${CONTAINER_NAME}/ 
    UNISON_AGENT_COMMAND="UNISON=${PWD}/.unison${CONTAINER_NAME} ${PWD}/unison -force ${UNISON_SYNC_PATH} ${UNISON_SYNC_PATH} ssh://\${UNISON_SSH_USER}@\${SSH_IP}:\${UNISON_SSH_PORT}//srv/jekyll 
        \${UNISON_REPEAT} -sshargs '-i ${HOME}/.ssh/jekyll_id_rsa${CONTAINER_NAME} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' ${DEBUG_UNISON}" 
    if [ "$UNISON_SYNC_PATH_CHE" != "" ]; then
        UNISON_AGENT_COMMAND="${UNISON_AGENT_COMMAND} &&
        UNISON=${PWD}/.unison${CONTAINER_NAME} ${PWD}/unison -force ${CHE_DOC_PATH} ${CHE_DOC_PATH} ssh://\${UNISON_SSH_USER}@\${SSH_IP}:\${UNISON_SSH_PORT}//srv/jekyll/_docs/che 
        \${UNISON_REPEAT} -sshargs '-i ${HOME}/.ssh/jekyll_id_rsa${CONTAINER_NAME} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' ${DEBUG_UNISON} &&
        UNISON=${PWD}/.unison${CONTAINER_NAME} ${PWD}/unison -force ${CHE_DOC_PATH}/assets/imgs ${CHE_DOC_PATH}/assets/imgs ssh://\${UNISON_SSH_USER}@\${SSH_IP}:\${UNISON_SSH_PORT}//srv/jekyll/_docs/assets/imgs 
        \${UNISON_REPEAT} -sshargs '-i ${HOME}/.ssh/jekyll_id_rsa${CONTAINER_NAME} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' ${DEBUG_UNISON} &&
        UNISON=${PWD}/.unison${CONTAINER_NAME} ${PWD}/unison -force ${UNISON_SYNC_PATH}/_docs/assets/imgs/codenvy ${UNISON_SYNC_PATH}/_docs/assets/imgs/codenvy ssh://\${UNISON_SSH_USER}@\${SSH_IP}:\${UNISON_SSH_PORT}//srv/jekyll/_docs/assets/imgs/codenvy 
        \${UNISON_REPEAT} -sshargs '-i ${HOME}/.ssh/jekyll_id_rsa${CONTAINER_NAME} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' ${DEBUG_UNISON}" 
  
    else
        UNISON_AGENT_COMMAND="${UNISON_AGENT_COMMAND} && 
        UNISON=${PWD}/.unison${CONTAINER_NAME} ${PWD}/unison -force ${UNISON_SYNC_PATH}/_docs/assets/imgs ${UNISON_SYNC_PATH}/_docs/assets/imgs ssh://\${UNISON_SSH_USER}@\${SSH_IP}:\${UNISON_SSH_PORT}//srv/jekyll/_docs/assets/imgs 
        \${UNISON_REPEAT} -sshargs '-i ${HOME}/.ssh/jekyll_id_rsa${CONTAINER_NAME} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' ${DEBUG_UNISON}" 
    fi
    
    
    export JEKYLL_SERVE_COMPLETE=false
    JEKYLL_COMMAND="docker exec ${CONTAINER_NAME} jekyll serve --force_polling --watch --incremental"
  }
  
check_status() {
    status=$?
    
	if [ $status -ne 0 ]; then
	  if [ $status -ne 3 ]; then
	    error "ERROR: Fatal error occurred ($status)"
	    stop_sync
	  else
	    warn "Error occurred ($status)"
	  fi
	fi
        
}

check_status_unison() {
    status=$?
    
	if [ $status -ne 0 ]; then
	  if [ $status -ne 1 ]; then
	    error "ERROR Unison: Fatal error occurred ($status)"
	    stop_sync
	  else
	    warn "Error occurred ($status)."
	  fi
	fi
        
}

parse_command_line () {
    USAGE="
jekyll.sh <docs-path> [<port>]
    <port>    Port to bind Jekyll server too. Default port=82."
  PORT="82"
  DOC_PATH=""
  CHE_DOC_PATH=""
  if [ $# -ne 0 ]; then
    if [ "$1" = "--help" ]; then
        usage
        return 1
    else
        if [ ! -d $2 ]; then
            error "Could not find directory specified: $2"
            usage
            return 1
        fi
        DOC_PATH="${2}"
        
        if [ $# -eq 3 ]; then
            if [ -d $3 ]; then
                CHE_DOC_PATH="${3}"
            fi
        fi
        
        if [ $1 -ne 0 ]; then
          PORT="${1}"
        fi
    fi
  else
    usage
    return 1
  fi
  # used in compose file
  export JEKYLL_BIND_PORT="${PORT}:"
  export CONTAINER_NAME="codenvy_docs_${PORT}_port"
}

usage () {
  printf "%s" "${USAGE}"
}

info() {
  printf  "${GREEN}INFO:${NC} %s\n" "${1}"
}

warn() {
  printf  "${RED}WARNING:${NC} %s\n" "${1}"
}

debug() {
  printf  "${BLUE}DEBUG:${NC} %s\n" "${1}"
}

error() {
  echo  "---------------------------------------"
  echo "!!!"
  echo "!!! ${1}"
  echo "!!!"
  echo  "---------------------------------------"
  return 1
}

stop_sync() {
  echo ""
  info "Received interrupt signal. Exiting."
    
  # Trapping SIGINTs so we can send them back to $bg_pid.
  kill -9 $bg_pid
    
  # In the meantime, wait for $bg_pid to end.
  wait $bg_pid
  
  exit 1
}

sync_folders() {
    # UNISON_REPEAT="-repeat 2"
    info  "Syncing..."
    while [ 1 ]
    do
        sleep 2
        eval ${UNISON_AGENT_COMMAND}
        check_status_unison
        printf  " "
    done
}

docker_installed() {
    DOCKER_BIN="/usr/bin/docker"
    
    if [ ! -e $DOCKER_BIN ]; then
        info Docker does NOT exists. Installing...
        export DEBIAN_FRONTEND=noninteractive
        sudo apt-get update
        sudo apt-get -y install apt-transport-https ca-certificates
        sudo apt-key adv --keyserver hkp://ha.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
        echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" | sudo tee /etc/apt/sources.list.d/docker.list
        sudo apt-get update
        apt-cache policy docker-engine
        sudo apt-get update
        sudo apt-get -y install docker-engine
        sudo apt-get -y install python-pip
        sudo pip install docker-compose        
    fi
}

# on callback, kill the last background process, which is `tail -f /dev/null` and execute the specified handler
trap 'stop_sync' 1 15 2

init_logging
parse_command_line "$@"
init_global_variables
docker_installed
mkdir -p /root/.ssh
rm -rf ../_site

if [ ! -e /var/run/docker.sock ]; then
    error "(${CHE_MINI_PRODUCT_NAME} Jekyll): File /var/run/docker.sock does not exist. Add to server extra volume mounts and restart server."
    exit 1
fi
eval ${DOCKER_CLEAN_OLD_COMMAND}


# docker-compose had error when put into eval. Maybe due to losing current directory value of build.
info "(${CHE_MINI_PRODUCT_NAME} Jekyll): Starting Jekyll container. Jekyll server will start after initial unison sync of /srv/jekyll folder."
if [ "$DEBUG" = "" ]; then
    docker-compose --file "${REFERENCE_CONTAINER_COMPOSE_FILE}" -p "${CONTAINER_NAME}" up -d --no-recreate docs
else
{
    docker-compose --file "${REFERENCE_CONTAINER_COMPOSE_FILE}" -p "${CONTAINER_NAME}" up -d --no-recreate docs
} > /dev/null 2>&1
fi
check_status
info "(${CHE_MINI_PRODUCT_NAME} Jekyll): Compose up complete."
info "${COPY_SSHKEY_COMMAND}"
eval ${COPY_SSHKEY_COMMAND}
check_status
info "(${CHE_MINI_PRODUCT_NAME} Jekyll): SSH key copy complete."

export SSH_IP=$(docker inspect --format='{{.NetworkSettings.Gateway}}' $(docker ps -aq --filter "name=${CONTAINER_NAME}") )
if [ "${SSH_IP}" = "" ]; then
    error "(${CHE_MINI_PRODUCT_NAME} Jekyll): Something went wrong. No gateway address assigned to container." 
fi
export UNISON_SSH_PORT=$(docker inspect --format='{{(index (index .NetworkSettings.Ports "22/tcp") 0).HostPort}}' $(docker ps -aq --filter "name=${CONTAINER_NAME}") )
info "(${CHE_MINI_PRODUCT_NAME} Jekyll): UNISON_SSH_PORT: $UNISON_SSH_PORT ."
export JEKYLL_PORT=$(docker inspect --format='{{(index (index .NetworkSettings.Ports "4000/tcp") 0).HostPort}}' $(docker ps -aq --filter "name=${CONTAINER_NAME}") )
export UNISON_SSH_USER=$(docker inspect --format='{{.Config.User}}' $(docker ps -aq --filter "name=${CONTAINER_NAME}") )

info "(${CHE_MINI_PRODUCT_NAME} Jekyll): Starting Initial sync to Jekyll docker container... Please wait."
START_TIME=$(date +%s)
eval ${UNISON_AGENT_COMMAND}
check_status
ELAPSED_TIME=$(expr $(date +%s) - $START_TIME)
info "(${CHE_MINI_PRODUCT_NAME} Jekyll): Initial sync to Jekyll docker container took $ELAPSED_TIME seconds."
info "(${CHE_MINI_PRODUCT_NAME} Jekyll): Starting Jekyll server at http://<host ip>:${JEKYLL_PORT}/."
sync_folders &
bg_pid=$!
info "(${CHE_MINI_PRODUCT_NAME} Jekyll): Background sync continues every 2 seconds."
info "(${CHE_MINI_PRODUCT_NAME} Jekyll): This terminal will block while the synchronization continues."
info "(${CHE_MINI_PRODUCT_NAME} Jekyll): To stop, issue a SIGTERM or SIGINT, usually CTRL-C."

eval ${JEKYLL_COMMAND}
check_status
