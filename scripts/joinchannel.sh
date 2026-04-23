#!/bin/bash

. ./utils.sh
. ./global.sh
. ./fabric-var.sh

function joinPeerIfNeeded() {
local PEER_ADDR=$1
local CH_NAME=$2
local join_output
local res

export CORE_PEER_ADDRESS=${PEER_ADDR}

join_output=$(peer channel join -b ../channelops/${CH_NAME}.pb 2>&1)
res=$?

printf "%s\n" "${join_output}"

if [ $res -eq 0 ]; then
      infoln "Peer ${CORE_PEER_ADDRESS} Successfully joined channel ${CH_NAME}"
      return 0
fi

if printf "%s" "${join_output}" | grep -q "already exists with state \\[ACTIVE\\]"; then
      infoln "Peer ${CORE_PEER_ADDRESS} is already joined to channel ${CH_NAME}; continuing."
      return 0
fi

fatalln "Peer ${CORE_PEER_ADDRESS} failed to join channel ${CH_NAME}."
return 1
}

function fetchBlockAndJoinChannel(){

export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=${orgName}
local peer_admin_msp_dir="${PEER_ADMIN_MSP_DIR:-}"
peer_admin_msp_dir="$(resolve_repo_path "${peer_admin_msp_dir}")"
export CORE_PEER_MSPCONFIGPATH=${peer_admin_msp_dir}
export CORE_PEER_TLS_ROOTCERT_FILE=${fabricCACert}
local ORDERER_TLS_CA_FILE=${ORDERER_TLS_CA_CERT}
local ORDERER_ENDPOINT=${ORDERER_ADDRESS}
local ORDERER_TLS_HOSTNAME=${ORDERER_TLS_HOSTNAME_OVERRIDE}
local ORDERER_TLS_HOSTNAME_ARGS=()
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

if [[ ${peer_admin_msp_dir} = " " || ${peer_admin_msp_dir} = "" ]]; then 
   errorln " PEER_ADMIN_MSP_DIR is not specified "
   exit 1
fi


if [[ ${CORE_PEER_LOCALMSPID} = " " || ${CORE_PEER_LOCALMSPID} = "" ]]; then 
   errorln " CORE_PEER_LOCALMSPID is not specified "
   exit 1
fi

export CORE_PEER_ADDRESS=peer0.${orgDomain}:7051

if [[ -n "${ORDERER_TLS_HOSTNAME}" ]]; then
   ORDERER_TLS_HOSTNAME_ARGS=(--ordererTLSHostnameOverride "${ORDERER_TLS_HOSTNAME}")
fi


infoln "Fetching the 0th block for the channel's ledger"

mkdir -p ../channelops
set -x
peer channel fetch 0 ../channelops/${CH_NAME}.pb  -o $ORDERER_ENDPOINT --tls --cafile $ORDERER_TLS_CA_FILE "${ORDERER_TLS_HOSTNAME_ARGS[@]}" -c ${CH_NAME}
res=$?
set +x

if [ $res -ne 0 ]; then
      fatalln "Failed to fetch config block ..."
      exit 1
fi

infoln "Successfully fetched block for peers to join"

	local i
	local peer_addr
	local peer_port

	for ((i=0; i<${peerCount}; i++)); do
	      peer_port=$((7051 + (i * 1000)))
	      peer_addr="peer${i}.${orgDomain}:${peer_port}"
	      joinPeerIfNeeded "${peer_addr}" "${CH_NAME}" || exit 1
	done


}

fetchBlockAndJoinChannel
