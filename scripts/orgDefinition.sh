#!/bin/bash

. ./global.sh
. ./utils.sh

function CreateOrgDefinition(){
set -e
cp ../templates/configtx-template.yaml ../hlf/${RUNNER_MODE}/${orgName}/configtx.yaml
sed -i -e "s/<OrgName>/${orgName}/g"  ../hlf/${RUNNER_MODE}/${orgName}/configtx.yaml
set -x
configtxgen -printOrg ${orgName} -configPath ../hlf/${RUNNER_MODE}/${orgName}  > ../hlf/${RUNNER_MODE}/${orgName}/${orgName}.json
set +x
set +e
}

CreateOrgDefinition