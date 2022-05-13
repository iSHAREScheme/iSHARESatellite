#!/bin/bash

. ./utils.sh
. ./global.sh
. ./fabric-var.sh

function installChaincode (){

export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=${orgName}
# PEER_ADMIN_MSP_DIR=$(cd ../app/${RUNNER_MODE}/${orgName}/crypto/users/Admin@${orgDomain}/msp && echo $(pwd))
export CORE_PEER_MSPCONFIGPATH=${PEER_ADMIN_MSP_DIR}
export CORE_PEER_TLS_ROOTCERT_FILE=${fabricCACert}
local ORDERER_TLS_CA_FILE=${ORDERER_TLS_CA_CERT}
local ORDERER_ENDPOINT=${ORDERER_ADDRESS}
local CH_NAME=${CHANNEL_NAME}

export CORE_PEER_ADDRESS=peer0.${orgDomain}:7051

CC_PATH=$(cd ../chaincode && echo $(pwd))/ishare.tgz
set -e
set -x
peer lifecycle chaincode install $CC_PATH
res=$?
set +x
if [ $res -ne 0 ]; then 
   errorln " Error while Installing the Chaincode "
   exit 1
fi

export CORE_PEER_ADDRESS=peer1.${orgDomain}:8051

set -x
peer lifecycle chaincode install $CC_PATH
res=$?
set +x
if [ $res -ne 0 ]; then 
   errorln " Error while Installing the Chaincode "
   exit 1
fi

set +e

}

installChaincode