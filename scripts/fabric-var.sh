#!/bin/bash

fabric_ca_cert_dir="${REPO_ROOT}/hlf/${RUNNER_MODE}/${orgName}/fabric-ca/certs"
fabricCACert="${fabric_ca_cert_dir}/$(ls "${fabric_ca_cert_dir}" | grep pem | head -n 1)"
fabricCAPem="${fabric_ca_cert_dir}/priv_sk"
export CRYPTO_PATH="${REPO_ROOT}/hlf/${RUNNER_MODE}/${orgName}/crypto"
export CA_CRYPTO_PATH="${CRYPTO_PATH}/fabca"
export FABRIC_CFG_PATH="${REPO_ROOT}/config"
