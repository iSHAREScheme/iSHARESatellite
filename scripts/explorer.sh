#!/bin/bash

. ./utils.sh
. ./global.sh
. ./fabric-var.sh

function parseExplorerConfigAndUP(){

set -e
# Seed Explorer from peer0 only. Discovery expands the topology after connect,
# and this avoids fresh multi-peer installs getting stuck before projection starts.
cp ../templates/profile-template.json ../explorer/profile.json
adminCertFile=/tmp/crypto/users/Admin@${orgName}/msp/signcerts/$(ls -t ../hlf/${RUNNER_MODE}/${orgName}/crypto/users/Admin@${orgName}/msp/signcerts | grep pem | head -n 1)
adminKeyFile=/tmp/crypto/users/Admin@${orgName}/msp/keystore/$(ls -t ../hlf/${RUNNER_MODE}/${orgName}/crypto/users/Admin@${orgName}/msp/keystore | grep sk | head -n 1)
tlsCertFile=$(ls -t ../hlf/${RUNNER_MODE}/${orgName}/crypto/msp/tlscacerts | grep -E 'pem$' | head -n 1)
if [[ "${tlsCertFile}" = " " || "${tlsCertFile}" = "" ]]; then
    errorln " Unable to resolve TLS CA cert from ../hlf/${RUNNER_MODE}/${orgName}/crypto/msp/tlscacerts "
    exit 1
fi
tlsCert=/tmp/crypto/msp/tlscacerts/${tlsCertFile}
sed -i -e "s/<orgName>/${orgName}/g" -e "s/<orgDomain>/${orgDomain}/g" -e "s%<adminCertFile>%${adminCertFile}%g" \
-e "s%<tlscaCertFile>%${tlsCert}%g" -e "s%<adminPrivateKey>%${adminKeyFile}%g" -e "s/<CHANNEL_NAME>/${CHANNEL_NAME}/g" ../explorer/profile.json
set +e

cp ../templates/explorer-docker-compose-template.yaml ../explorer/explorer-docker-compose.yaml

cryptoPath=$(cd ../hlf/${RUNNER_MODE}/${orgName}/crypto && echo $(pwd))
sed -i -e "s%<cryptoPath>%${cryptoPath}%g" ../explorer/explorer-docker-compose.yaml

# Reset clearly broken explorerdb data dir (non-empty but no PG_VERSION).
if [[ -d ../explorer/docker_data/explorer_ishare ]] && [[ ! -f ../explorer/docker_data/explorer_ishare/PG_VERSION ]]; then
  if find ../explorer/docker_data/explorer_ishare -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
    ts=$(date +%Y%m%d-%H%M%S)
    warnln "Detected incomplete explorerdb data dir, backing up to ../explorer/docker_data/explorer_ishare.bak-${ts}"
    mv ../explorer/docker_data/explorer_ishare "../explorer/docker_data/explorer_ishare.bak-${ts}"
  fi
fi
mkdir -p ../explorer/docker_data/explorer_ishare
chown -R 70:70 ../explorer/docker_data/explorer_ishare || true
chmod -R 700 ../explorer/docker_data/explorer_ishare || true

run_compose -f ../explorer/explorer-docker-compose.yaml up -d 2>&1
}

parseExplorerConfigAndUP
