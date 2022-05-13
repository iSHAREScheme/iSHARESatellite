#!/bin/bash

. ./utils.sh
. ./global.sh
. ./fabric-var.sh

function anchorPeerInChannel(){

export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=${orgName}
PEER_ADMIN_MSP_DIR=$(cd ../app/${RUNNER_MODE}/${orgName}/crypto/peerOrganizations/${orgDomain}/users/Admin@${orgDomain}/msp && echo $(pwd))
export CORE_PEER_MSPCONFIGPATH=${PEER_ADMIN_MSP_DIR}
export CORE_PEER_TLS_ROOTCERT_FILE=${fabricCACert}
local ORDERER_TLS_CA_FILE=${ORDERER_TLS_CA_CERT}
local ORDERER_ENDPOINT=${ORDERER_ADDRESS}
local CH_NAME=${CHANNEL_NAME}
local PEER_ID=${ANCHOR_PEER_HOSTNAME}
local PORT=${ANCHOR_PEER_PORT_NUMBER}

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


infoln "Fetching the config block of the channel ${CH_NAME}"

mkdir -p ../channelops
set -x
peer channel fetch config ../channelops/config_block.pb  -o $ORDERER_ENDPOINT --tls --cafile $ORDERER_TLS_CA_FILE -c ${CH_NAME}
res=$?
set +x

if [ $res -ne 0 ]; then
      fatalln "Failed to fetch config block ..."
      exit 1
fi


infoln "Decoding config block to JSON and isolating config"
set -x
configtxlator proto_decode --input ../channelops/config_block.pb --type common.Block --output ../channelops/config_block.json
jq .data.data[0].payload.data.config ../channelops/config_block.json > ../channelops/config.json
set +x

set -e
set -x
jq '.channel_group.groups.Application.groups.'${orgName}'.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "'${PEER_ID}'","port": '${PORT}'}]},"version": "0"}}' ../channelops/config.json > ../channelops/modified_config.json
set +x
set +e

set -e
set -x
configtxlator proto_encode --input ../channelops/config.json --type common.Config --output ../channelops/config.pb
configtxlator proto_encode --input ../channelops/modified_config.json --type common.Config --output ../channelops/modified_config.pb
configtxlator compute_update --channel_id $CH_NAME --original ../channelops/config.pb --updated ../channelops/modified_config.pb --output ../channelops/config_update.pb
configtxlator proto_decode --input ../channelops/config_update.pb --type common.ConfigUpdate --output ../channelops/config_update.json
echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CH_NAME'", "type":2}},"data":{"config_update":'$(cat ../channelops/config_update.json)'}}}' | jq . > ../channelops/config_update_in_envelope.json
configtxlator proto_encode --input ../channelops/config_update_in_envelope.json --type common.Envelope --output ../channelops/config_update_in_envelope.pb
set +x
set +e

set -x
peer channel update -f ../channelops/config_update_in_envelope.pb  -c $CH_NAME  -o $ORDERER_ENDPOINT --tls --cafile $ORDERER_TLS_CA_FILE
res=$?
set +x

if [ $res -ne 0 ]; then
      fatalln "Failed to Add org to channel..."
      exit 1
fi



}

anchorPeerInChannel