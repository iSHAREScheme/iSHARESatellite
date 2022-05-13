#!/bin/bash

. ./global.sh
. ./utils.sh

function FabricCAUP(){

local orgDomain=$1
mkdir -p ../hlf/${RUNNER_MODE}/${orgName}/fabric-ca/certs
cp ../openssl/tls-rca/${RUNNER_MODE}/${orgName}/private/priv_sk ../hlf/${RUNNER_MODE}/${orgName}/fabric-ca/certs
cp ../openssl/tls-rca/${RUNNER_MODE}/${orgName}/certs/ca.${orgDomain}-cert.pem ../hlf/${RUNNER_MODE}/${orgName}/fabric-ca/certs

cp ../templates/fabric-ca-server-config.yaml ../hlf/${RUNNER_MODE}/${orgName}/fabric-ca/fabric-ca-server-config.yaml
cp ../templates/docker-compose-fabric-ca-template.yaml ../hlf/${RUNNER_MODE}/${orgName}/fabric-ca/docker-compose-fabric-ca.yaml
sed -i -e "s/<orgDomain>/${orgDomain}/g" -e "s/<ENROLLMENT_SECRET>/${ENROLLMENT_SECRET}/g" ../hlf/${RUNNER_MODE}/${orgName}/fabric-ca/docker-compose-fabric-ca.yaml

infoln "Bringing Fabric CA UP ...."
docker-compose -f ../hlf/${RUNNER_MODE}/${orgName}/fabric-ca/docker-compose-fabric-ca.yaml up -d 2>&1
sleep 5
caContainer=$(docker-compose -f ../hlf/${RUNNER_MODE}/${orgName}/fabric-ca/docker-compose-fabric-ca.yaml logs ca.${orgDomain} | grep Listening )
if [ "${caContainer}" == "" ]; then
errorln "Failed to bring Fabric CA up"
exit 1
fi


infoln "Fabric CA server is Running now ..."

}

FabricCAUP $orgDomain