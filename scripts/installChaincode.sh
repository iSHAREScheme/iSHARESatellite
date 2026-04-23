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
local peer_admin_msp_dir="${PEER_ADMIN_MSP_DIR:-}"
peer_admin_msp_dir="$(resolve_repo_path "${peer_admin_msp_dir}")"
export CORE_PEER_MSPCONFIGPATH=${peer_admin_msp_dir}
export CORE_PEER_TLS_ROOTCERT_FILE=${fabricCACert}
local ORDERER_TLS_CA_FILE=${ORDERER_TLS_CA_CERT}
local ORDERER_ENDPOINT=${ORDERER_ADDRESS}
local CH_NAME=${CHANNEL_NAME}

if [[ ${peer_admin_msp_dir} = " " || ${peer_admin_msp_dir} = "" ]]; then
   errorln " PEER_ADMIN_MSP_DIR is not specified "
   exit 1
fi

export CORE_PEER_ADDRESS=peer0.${orgDomain}:7051

CC_PATH=$(cd ../chaincode && echo $(pwd))/ishare.tgz

	local i
	local peer_addr
	local peer_port

	for ((i=0; i<${peerCount}; i++)); do
	   peer_port=$((7051 + (i * 1000)))
	   peer_addr="peer${i}.${orgDomain}:${peer_port}"
	   installChaincodeOnPeer "${peer_addr}" "${CC_PATH}" || exit 1
	done

	}

installChaincode
