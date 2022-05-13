#!/bin/bash

. ./global.sh
. ./utils.sh

function GenerateFabricCACertsWithOpenssl(){
local orgDomain=$1
set -e
mkdir -p ../openssl/tls-rca/${RUNNER_MODE}/${orgName}/private ../openssl/tls-rca/${RUNNER_MODE}/${orgName}/certs ../openssl/tls-rca/${RUNNER_MODE}/${orgName}/newcerts ../openssl/tls-rca/${RUNNER_MODE}/${orgName}/crl
touch ../openssl/tls-rca/index.txt ../openssl/tls-rca/serial
echo 1000 > ../openssl/tls-rca/serial
echo 1000 > ../openssl/tls-rca/crlnumber
set -x
openssl ecparam -name prime256v1 -genkey -noout -out ../openssl/tls-rca/${RUNNER_MODE}/${orgName}/private/priv_sk
openssl req -config ../openssl/openssl_root-tls.cnf -new -x509 -sha256 -extensions v3_ca -key ../openssl/tls-rca/${RUNNER_MODE}/${orgName}/private/priv_sk \
-out ../openssl/tls-rca/${RUNNER_MODE}/${orgName}/certs/ca.${orgDomain}-cert.pem -days 3650 -subj "/C=SG/ST=Singapore/L=Singapore/O=${orgDomain}/OU=/CN=ca.${orgDomain}"
set +x
set +e
}

GenerateFabricCACertsWithOpenssl $orgDomain
infoln "Fabric CA certs are generated Successfully ...."

