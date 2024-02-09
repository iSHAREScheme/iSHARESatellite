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
    sudo chmod -R 777 ../hlf/${RUNNER_MODE}/${orgName}/crypto
    sudo mkdir -p ../hlf/${RUNNER_MODE}/${orgName}/peers/docker_data/couchdb.peer0.${orgDomain}                 
    sudo mkdir -p ../hlf/${RUNNER_MODE}/${orgName}/peers/docker_data/couchdb.peer0.${orgDomain}/opt/couchdb/data
    sudo mkdir -p ../hlf/${RUNNER_MODE}/${orgName}/peers/docker_data/peer0.${orgDomain}                 
    sudo mkdir -p ../hlf/${RUNNER_MODE}/${orgName}/peers/docker_data/couchdb.peer1.${orgDomain}                 
    sudo mkdir -p ../hlf/${RUNNER_MODE}/${orgName}/peers/docker_data/couchdb.peer1.${orgDomain}/opt/couchdb/data
    sudo mkdir -p ../hlf/${RUNNER_MODE}/${orgName}/peers/docker_data/peer1.${orgDomain}                 
    sudo chmod -R 777 ../hlf/${RUNNER_MODE}/${orgName}/peers/docker_data
    sudo chown -R 1001:1001 ../hlf/${RUNNER_MODE}/${orgName}/peers/docker_data
    sudo chmod -R 777 ../hlf/${RUNNER_MODE}/${orgName}/peers/peerConfig
    sudo chown -R 1001:1001 ../hlf/${RUNNER_MODE}/${orgName}/peers/peerConfig
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
