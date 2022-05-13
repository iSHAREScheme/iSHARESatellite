#!/bin/bash

. ./utils.sh
. ./global.sh
. ./fabric-var.sh

function parseExplorerConfigAndUP(){

set -e 
cp ../templates/profile-template.json ../explorer/profile.json
# adminCertFile=$(cd ../hlf/${RUNNER_MODE}/${orgName}/crypto/users/Admin@${orgName}/msp/signcerts && echo $(pwd))/$(ls  ../hlf/${RUNNER_MODE}/${orgName}/crypto/users/Admin@${orgName}/msp/signcerts | grep pem)
adminCertFile=/tmp/crypto/users/Admin@${orgName}/msp/signcerts/$(ls  ../hlf/${RUNNER_MODE}/${orgName}/crypto/users/Admin@${orgName}/msp/signcerts | grep pem)
adminKeyFile=/tmp/crypto/users/Admin@${orgName}/msp/keystore/$(ls ../hlf/${RUNNER_MODE}/${orgName}/crypto/users/Admin@${orgName}/msp/keystore | grep sk)

tlsCert=/tmp/crypto/msp/tlscacerts/tls-localhost-7054.pem
sed -i -e "s/<orgName>/${orgName}/g" -e "s/<orgDomain>/${orgDomain}/g" -e "s%<adminCertFile>%${adminCertFile}%g" \
-e "s%<tlscaCertFile>%${tlsCert}%g" -e "s%<adminPrivateKey>%${adminKeyFile}%g" -e "s/<CHANNEL_NAME>/${CHANNEL_NAME}/g" ../explorer/profile.json
set +e

cp ../templates/explorer-docker-compose-template.yaml ../explorer/explorer-docker-compose.yaml

cryptoPath=$(cd ../hlf/${RUNNER_MODE}/${orgName}/crypto && echo $(pwd))
sed -i -e "s%<cryptoPath>%${cryptoPath}%g" ../explorer/explorer-docker-compose.yaml

docker-compose -f ../explorer/explorer-docker-compose.yaml up -d 2>&1
}

parseExplorerConfigAndUP