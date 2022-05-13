#!/bin/bash

. ./utils.sh
. ./global.sh

function createChaincodeInstance(){
    set -e
    cp ../templates/cc-docker-compose-template.yaml ../chaincode/cc-docker-compose-template.yaml
    sed -i -e "s/<orgName>/${orgName}/g" ../chaincode/cc-docker-compose-template.yaml
    docker-compose -f ../chaincode/cc-docker-compose-template.yaml up -d 
    infoln "chaincode instance is created, check the status by using below command .... "
    infoln "docker-compose -f ../chaincode/cc-docker-compose-template.yaml ps"
    set +e
}

if [[ ${orgName} = " " || ${orgName} = "" ]]; then 
   errorln " orgName is not specified "
   exit 1
fi
createChaincodeInstance