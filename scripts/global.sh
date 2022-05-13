#!/bin/bash

REGISTERAR_NAME=admin
ENROLLMENT_SECRET=adminpw
RUNNER_MODE="${ENVIRONMENT}"
FABRIC_CA_ADDRESS=localhost:7054
orgName="${ORG_NAME}"
domain="${SUB_DOMAIN}"
domainName="${SUB_DOMAIN}"
peerCount=2
ordererCount=0
if [[ ${ORG_NAME} = " " || ${ORG_NAME} = "" ]]; then 
   echo " ORG_NAME is not specified "
   exit 1
fi
str=${ORG_NAME}

if [[ $str =~ ['!@#$%^&*()_+.,<>?/\-'] ]]; then
    echo "these characers are not allowed for ORG_NAME !@#$%^&*()_+.,<>?/\-  "
    exit 1
fi

if [ ${#str} -ge 18 ]; then
    echo " ORG_NAME length should not exceed above 17  "
    exit 1
fi

re="[[:space:]]+"
if [[ $str =~ $re ]]; then
  echo "ORG_NAME contains one or more spaces"
  exit 1
fi


if [[ ${SUB_DOMAIN} = " " || ${SUB_DOMAIN} = "" ]]; then 
   echo " SUB_DOMAIN is not specified "
   exit 1
fi
if [[ ${ENVIRONMENT} = " " || ${ENVIRONMENT} = "" ]]; then 
   echo " ENVIRONMENT is not specified "
   exit 1
fi
orgDomain=${ORG_NAME}.${SUB_DOMAIN}
export PATH=$PATH:$(cd ../bin && echo $(pwd))

