#!/bin/bash

. ./global.sh
. ./utils.sh

function GenerateFabricCACertsWithOpenssl(){
local orgDomain=$1
local ca_dir="../openssl/tls-rca/${RUNNER_MODE}/${orgName}"
local ca_key="${ca_dir}/private/priv_sk"
local ca_cert="${ca_dir}/certs/ca.${orgDomain}-cert.pem"
set -e
mkdir -p "${ca_dir}/private" "${ca_dir}/certs" "${ca_dir}/newcerts" "${ca_dir}/crl"

if [[ -f "${ca_key}" && -f "${ca_cert}" ]]; then
  infoln "Fabric CA cert already exists at ${ca_cert}; keeping existing CA material."
  set +e
  return 0
fi

if [[ -f "${ca_key}" || -f "${ca_cert}" ]]; then
  errorln "Partial Fabric CA material exists for ${orgDomain}; refusing to overwrite."
  errorln "Expected both ${ca_key} and ${ca_cert}, or neither. Remove the partial files only if you intend to regenerate CA material."
  exit 1
fi

touch ../openssl/tls-rca/index.txt ../openssl/tls-rca/serial
echo 1000 > ../openssl/tls-rca/serial
echo 1000 > ../openssl/tls-rca/crlnumber

set -x
openssl ecparam -name prime256v1 -genkey -noout -out "${ca_key}"
openssl req -config ../openssl/openssl_root-tls.cnf -new -x509 -sha256 -extensions v3_ca -key "${ca_key}" \
-out "${ca_cert}" -days 3650 -subj "/C=SG/ST=Singapore/L=Singapore/O=${orgDomain}/OU=/CN=ca.${orgDomain}"
set +x
set +e
}

GenerateFabricCACertsWithOpenssl "${orgDomain}"
infoln "Fabric CA certs are ready."
