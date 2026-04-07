#!/bin/bash

. ./utils.sh
. ./global.sh
. ./fabric-var.sh

function installChaincodeOnPeer() {
local PEER_ADDR=$1
local CC_PATH=$2
local install_output
local res

export CORE_PEER_ADDRESS=${PEER_ADDR}
install_output=$(peer lifecycle chaincode install "${CC_PATH}" 2>&1)
res=$?

printf "%s\n" "${install_output}"

if [ $res -eq 0 ]; then
   infoln "Chaincode installed on ${CORE_PEER_ADDRESS}"
   return 0
fi

if printf "%s" "${install_output}" | grep -q "chaincode already successfully installed"; then
   infoln "Chaincode already installed on ${CORE_PEER_ADDRESS}; continuing."
   return 0
fi

errorln "Error while installing chaincode on ${CORE_PEER_ADDRESS}"
return 1
}

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

installChaincodeOnPeer "peer0.${orgDomain}:7051" "${CC_PATH}" || exit 1
installChaincodeOnPeer "peer1.${orgDomain}:8051" "${CC_PATH}" || exit 1

}

installChaincode
