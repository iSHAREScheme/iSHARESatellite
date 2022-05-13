#!/bin/bash

C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_BLUE='\033[0;34m'
C_YELLOW='\033[1;33m'


# println echos string
function println() {
  echo -e "$1"
}

# errorln echos i red color
function errorln() {
  println "${C_RED}${1}${C_RESET}"
}

# successln echos in green color
function successln() {
  println "${C_GREEN}${1}${C_RESET}"
}

# infoln echos in blue color
function infoln() {
  println "${C_BLUE}${1}${C_RESET}"
}

# warnln echos in yellow color
function warnln() {
  println "${C_YELLOW}${1}${C_RESET}"
}

# fatalln echos in red color and exits with fail status
function fatalln() {
  errorln "$1"
  exit 1
}

function getSKIFromCert(){
local certFile=$1  
SKI=$(openssl x509 -noout -pubkey -in ${certFile} | openssl ec -pubin -outform d | dd ibs=26 skip=1 | openssl dgst -sha256 | grep "stdin" | awk {print} | sed -e "s/(stdin)= //g" )
echo $SKI
}

function createOrgMSPDirForConfigTX(){
set -e
set -x
mkdir -p $CRYPTO_PATH/msp/{admincerts,cacerts,tlscacerts}
cp $CA_CRYPTO_PATH/ca-admin/msp/cacerts/*  $CRYPTO_PATH/msp/cacerts/      
cp $CA_CRYPTO_PATH/ca-admin/tls/tlscacerts/* $CRYPTO_PATH/msp/tlscacerts/
mkdir -p $CA_CRYPTO_PATH/ca-admin/msp/admincerts
cp $CRYPTO_PATH/users/Admin@${orgName}/msp/signcerts/*  $CRYPTO_PATH/msp/admincerts/
set +x
set +e
}

function createOrgAdminSDKDir(){
  set -e
  mkdir -p ../app/${RUNNER_MODE}/${orgName}/crypto/peerOrganizations/${orgDomain}/users/Admin@${orgDomain}/msp/{admincerts,cacerts,keystore,signcerts,tlscacerts}
  cp $CRYPTO_PATH/users/Admin@${orgName}/msp/signcerts/* ../app/${RUNNER_MODE}/${orgName}/crypto/peerOrganizations/${orgDomain}/users/Admin@${orgDomain}/msp/signcerts/Admin@${orgDomain}-cert.pem
  cp $CRYPTO_PATH/users/Admin@${orgName}/msp/keystore/*  ../app/${RUNNER_MODE}/${orgName}/crypto/peerOrganizations/${orgDomain}/users/Admin@${orgDomain}/msp/keystore/priv_sk
  cp $CRYPTO_PATH/users/Admin@${orgName}/msp/cacerts/*  ../app/${RUNNER_MODE}/${orgName}/crypto/peerOrganizations/${orgDomain}/users/Admin@${orgDomain}/msp/cacerts/cacert.pem
  cp $CRYPTO_PATH/users/Admin@${orgName}/msp/signcerts/* ../app/${RUNNER_MODE}/${orgName}/crypto/peerOrganizations/${orgDomain}/users/Admin@${orgDomain}/msp/signcerts/Admin@${orgDomain}-cert.pem
  cp $CRYPTO_PATH/msp/tlscacerts/* ../app/${RUNNER_MODE}/${orgName}/crypto/peerOrganizations/${orgDomain}/users/Admin@${orgDomain}/msp/tlscacerts/tlscacert.pem
  cp ../app/${RUNNER_MODE}/${orgName}/crypto/peerOrganizations/${orgDomain}/users/Admin@${orgDomain}/msp/signcerts/Admin@${orgDomain}-cert.pem ../app/${RUNNER_MODE}/${orgName}/crypto/peerOrganizations/${orgDomain}/users/Admin@${orgDomain}/msp/admincerts/Admin@${orgDomain}-cert.pem
  set +e
}

export -f errorln
export -f successln
export -f infoln
export -f warnln