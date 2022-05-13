#!/bin/bash

. ./utils.sh
. ./global.sh
. ./fabric-var.sh

function fetchBlockAndJoinChannel(){

export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=${orgName}
PEER_ADMIN_MSP_DIR=$(cd ../app/${RUNNER_MODE}/${orgName}/crypto/peerOrganizations/${orgDomain}/users/Admin@${orgDomain}/msp && echo $(pwd))
export CORE_PEER_MSPCONFIGPATH=${PEER_ADMIN_MSP_DIR}
export CORE_PEER_TLS_ROOTCERT_FILE=${fabricCACert}
local ORDERER_TLS_CA_FILE=${ORDERER_TLS_CA_CERT}
local ORDERER_ENDPOINT=${ORDERER_ADDRESS}
local CH_NAME=${CHANNEL_NAME}

if [[ ${CHANNEL_NAME} = " " || ${CHANNEL_NAME} = "" ]]; then 
   errorln " CHANNEL_NAME is not specified "
   exit 1
fi

if [[ ${ORDERER_TLS_CA_FILE} = " " || ${ORDERER_TLS_CA_FILE} = "" ]]; then 
   errorln " ORDERER_TLS_CA_FILE is not specified "
   exit 1
fi

if [[ ${ORDERER_ENDPOINT} = " " || ${ORDERER_ENDPOINT} = "" ]]; then 
   errorln " ORDERER_ENDPOINT is not specified "
   exit 1
fi

if [[ ${CORE_PEER_TLS_ROOTCERT_FILE} = " " || ${CORE_PEER_TLS_ROOTCERT_FILE} = "" ]]; then 
   errorln " CORE_PEER_TLS_ROOTCERT_FILE is not specified "
   exit 1
fi

if [[ ${PEER_ADMIN_MSP_DIR} = " " || ${PEER_ADMIN_MSP_DIR} = "" ]]; then 
   errorln " PEER_ADMIN_MSP_DIR is not specified "
   exit 1
fi


if [[ ${CORE_PEER_LOCALMSPID} = " " || ${CORE_PEER_LOCALMSPID} = "" ]]; then 
   errorln " CORE_PEER_LOCALMSPID is not specified "
   exit 1
fi

export CORE_PEER_ADDRESS=peer0.${orgDomain}:7051


infoln "Fetching the 0th block for the channel's ledger"

mkdir -p ../channelops
set -x
peer channel fetch 0 ../channelops/${CH_NAME}.pb  -o $ORDERER_ENDPOINT --tls --cafile $ORDERER_TLS_CA_FILE -c ${CH_NAME}
res=$?
set +x

if [ $res -ne 0 ]; then
      fatalln "Failed to fetch config block ..."
      exit 1
fi

infoln "Successfully fetched block for peers to join"

set -x
peer channel join -b ../channelops/${CH_NAME}.pb
res=$?
set +x
if [ $res -ne 0 ]; then
      fatalln "Peer ${CORE_PEER_ADDRESS} failed to join channel $CH_NAME ...."
      exit 1
fi
infoln "Peer ${CORE_PEER_ADDRESS} Successfully joined  channel $CH_NAME"

export CORE_PEER_ADDRESS=peer1.${orgDomain}:8051
set -x
peer channel join -b ../channelops/${CH_NAME}.pb
res=$?
set +x
if [ $res -ne 0 ]; then
      fatalln "Peer ${CORE_PEER_ADDRESS} failed to join channel $CH_NAME ...."
      exit 1
fi

infoln "Peer ${CORE_PEER_ADDRESS} Successfully joined  channel $CH_NAME"


}

fetchBlockAndJoinChannel