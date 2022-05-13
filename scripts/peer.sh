#!/bin/bash

. ./utils.sh
. ./global.sh
. ./fabric-var.sh

function peerTemplateParse(){
    mkdir -p ../hlf/${RUNNER_MODE}/${orgName}/peers
    cp  -r  ../templates/peerConfig ../hlf/${RUNNER_MODE}/${orgName}/peers/
    set -e
    set -x
    chmod 777 -R ../hlf/${RUNNER_MODE}/${orgName}/peers
    set +x
    set +e
    cp  ../templates/docker-compose-hlf-template.yaml ../hlf/${RUNNER_MODE}/${orgName}/peers/docker-compose-hlf.yaml
    sed -i -e "s/<orgDomain>/${orgDomain}/g" -e "s/<orgName>/${orgName}/g" ../hlf/${RUNNER_MODE}/${orgName}/peers/docker-compose-hlf.yaml
}

function peersUp(){
set -e
set -x
docker-compose -f ../hlf/${RUNNER_MODE}/${orgName}/peers/docker-compose-hlf.yaml up -d
set +x
set +e
}

peerTemplateParse
peersUp