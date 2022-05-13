#!/bin/bash

fabricCACert=$(cd ../hlf/${RUNNER_MODE}/${orgName}/fabric-ca/certs && echo $(pwd))/$(ls ../hlf/${RUNNER_MODE}/${orgName}/fabric-ca/certs | grep pem)
fabricCAPem=$(cd ../hlf/${RUNNER_MODE}/${orgName}/fabric-ca/certs && echo $(pwd))/priv_sk
export CRYPTO_PATH=$(cd ../hlf/${RUNNER_MODE}/${orgName} && echo $(pwd))/crypto
export CA_CRYPTO_PATH=$CRYPTO_PATH/fabca
export FABRIC_CFG_PATH=$(cd ../config && echo $(pwd))