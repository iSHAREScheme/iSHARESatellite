#!/bin/bash

. ./utils.sh
. ./global.sh
. ./fabric-var.sh

function isChaincodeAlreadyApproved() {
local CH_NAME=$1
local CC_NAME=$2
local CC_SEQUENCE=$3
local query_output
local query_res

query_output=$(peer lifecycle chaincode queryapproved --channelID "${CH_NAME}" --name "${CC_NAME}" --sequence "${CC_SEQUENCE}" 2>&1)
query_res=$?
printf "%s\n" "${query_output}"

if [ $query_res -ne 0 ]; then
   return 1
fi

if printf "%s" "${query_output}" | grep -q "Approved chaincode definition"; then
   return 0
fi

return 1
}

function resolveChaincodePackageID(){
if [[ -n "${CC_PACKAGE_ID:-}" ]]; then
   echo "${CC_PACKAGE_ID}"
   return
fi

local label="${CHAINCODE_LABEL:-isharecc_1.0}"
local package_id
package_id=$(
  peer lifecycle chaincode queryinstalled \
    | grep "Label: ${label}$" \
    | sed -E 's/^Package ID: ([^,]+),.*$/\1/' \
    | head -n 1
)

if [[ -z "${package_id}" ]]; then
   echo "Unable to resolve chaincode package ID for label ${label}. Set CC_PACKAGE_ID or CHAINCODE_LABEL in your ENV_FILE." >&2
   return 1
fi

echo "${package_id}"
}

function approveAndCommitReadinessChaincode (){

export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=${orgName}
# PEER_ADMIN_MSP_DIR=$(cd ../app/${RUNNER_MODE}/${orgName}/crypto/users/Admin@${orgDomain}/msp && echo $(pwd))
export CORE_PEER_MSPCONFIGPATH=${PEER_ADMIN_MSP_DIR}
export CORE_PEER_TLS_ROOTCERT_FILE=${fabricCACert}
local ORDERER_TLS_CA_FILE=${ORDERER_TLS_CA_CERT}
local ORDERER_ENDPOINT=${ORDERER_ADDRESS}
local CH_NAME=${CHANNEL_NAME}
local CC_NAME=${CHAINCODE_NAME}
local CC_VERSION=${CHAINCODE_VERSION}
local CC_SEQUENCE=${CHAINCODE_SEQUENCE}
local CC_POLICY=${CHAINCODE_POLICY}

export CORE_PEER_ADDRESS=peer0.${orgDomain}:7051

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

if [[ ${CORE_PEER_ADDRESS} = " " || ${CORE_PEER_ADDRESS} = "" ]]; then 
   errorln " CORE_PEER_ADDRESS is not specified "
   exit 1
fi

if [[ ${CORE_PEER_LOCALMSPID} = " " || ${CORE_PEER_LOCALMSPID} = "" ]]; then 
   errorln " CORE_PEER_LOCALMSPID is not specified "
   exit 1
fi

if [[ ${CC_POLICY} = " " || ${CC_POLICY} = "" ]]; then 
   errorln " CC_POLICY is not specified "
   exit 1
fi

if [[ ${CHAINCODE_NAME} = " " || ${CHAINCODE_NAME} = "" ]]; then 
   errorln " CHAINCODE_NAME is not specified "
   exit 1
fi

if [[ ${CC_SEQUENCE} = " " || ${CC_SEQUENCE} = "" ]]; then 
   errorln " CC_SEQUENCE is not specified "
   exit 1
fi

if ! CC_PACKAGE_ID=$(resolveChaincodePackageID); then
   exit 1
fi

if isChaincodeAlreadyApproved "${CH_NAME}" "${CC_NAME}" "${CC_SEQUENCE}"; then
   infoln "Chaincode definition already approved for ${CORE_PEER_LOCALMSPID}; skipping approve step."
   return 0
fi

infoln "Using chaincode package ID ${CC_PACKAGE_ID}"
infoln "Performing Chaincode Approve "
set -x
peer lifecycle chaincode approveformyorg -o $ORDERER_ENDPOINT --tls --cafile $ORDERER_TLS_CA_FILE --channelID $CH_NAME --name $CC_NAME --version ${CHAINCODE_VERSION} --package-id $CC_PACKAGE_ID --sequence $CC_SEQUENCE --signature-policy "${CC_POLICY}" --waitForEvent
res=$?
set +x
if [ $res -ne 0 ]; then 
   if isChaincodeAlreadyApproved "${CH_NAME}" "${CC_NAME}" "${CC_SEQUENCE}"; then
      infoln "Chaincode definition is already approved for ${CORE_PEER_LOCALMSPID}; continuing."
      return 0
   fi
   errorln " Error while approving the Chaincode "
   exit 1
fi

# infoln "Performing Chaincode checkcommitreadiness "

# set -x
# peer lifecycle chaincode checkcommitreadiness -o $ORDERER_ENDPOINT --channelID $CH_NAME --tls --cafile $ORDERER_TLS_CA_FILE --name $CC_NAME --version ${CHAINCODE_VERSION}  --sequence $CC_SEQUENCE --signature-policy "${CC_POLICY}" --output json
# res=$?
# set +x
# if [ $res -ne 0 ]; then 
#    errorln " Error while performing checkcommitreadiness in Chaincode "
#    exit 1
# fi

} 

approveAndCommitReadinessChaincode
