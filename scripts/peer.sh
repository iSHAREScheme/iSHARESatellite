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
    if [[ "${PEER_COUNT:-2}" == "1" ]]; then
      # Render single-peer deployments without stale peer1 services.
      awk '
      BEGIN {skip=0}
      {
        if ($0 ~ /^  couchdb\.peer1\./) { skip=1; next }
        if ($0 ~ /^  peer1\./) { skip=1; next }
        if (skip==1) {
          if ($0 ~ /^  [^[:space:]]/ && $0 !~ /^  (couchdb\.peer1\.|peer1\.)/) {
            skip=0
            print $0
            next
          }
          next
        }
        print $0
      }' ../hlf/${RUNNER_MODE}/${orgName}/peers/docker-compose-hlf.yaml \
      > ../hlf/${RUNNER_MODE}/${orgName}/peers/docker-compose-hlf.yaml.tmp
      mv ../hlf/${RUNNER_MODE}/${orgName}/peers/docker-compose-hlf.yaml.tmp ../hlf/${RUNNER_MODE}/${orgName}/peers/docker-compose-hlf.yaml
    fi
    sudo chmod -R 777 ../hlf/${RUNNER_MODE}/${orgName}/crypto
    sudo mkdir -p ../hlf/${RUNNER_MODE}/${orgName}/peers/docker_data/couchdb.peer0.${orgDomain}                 
    sudo mkdir -p ../hlf/${RUNNER_MODE}/${orgName}/peers/docker_data/couchdb.peer0.${orgDomain}/opt/couchdb/data
    sudo mkdir -p ../hlf/${RUNNER_MODE}/${orgName}/peers/docker_data/peer0.${orgDomain}                 
    if [[ "${PEER_COUNT:-2}" != "1" ]]; then
        sudo mkdir -p ../hlf/${RUNNER_MODE}/${orgName}/peers/docker_data/couchdb.peer1.${orgDomain}                 
        sudo mkdir -p ../hlf/${RUNNER_MODE}/${orgName}/peers/docker_data/couchdb.peer1.${orgDomain}/opt/couchdb/data
        sudo mkdir -p ../hlf/${RUNNER_MODE}/${orgName}/peers/docker_data/peer1.${orgDomain}
    fi
    sudo chmod -R 777 ../hlf/${RUNNER_MODE}/${orgName}/peers/docker_data
    sudo chown -R 1001:1001 ../hlf/${RUNNER_MODE}/${orgName}/peers/docker_data
    sudo chmod -R 777 ../hlf/${RUNNER_MODE}/${orgName}/peers/peerConfig
    sudo chown -R 1001:1001 ../hlf/${RUNNER_MODE}/${orgName}/peers/peerConfig
}

function peersUp(){
set -e
set -x
run_compose -f ../hlf/${RUNNER_MODE}/${orgName}/peers/docker-compose-hlf.yaml up -d
set +x
set +e
}

peerTemplateParse
peersUp
