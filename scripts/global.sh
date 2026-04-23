#!/bin/bash

GLOBAL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${REPO_ROOT:=$(cd "${GLOBAL_SCRIPT_DIR}/.." && pwd)}"
BIN_DIR="${REPO_ROOT}/bin"

REGISTERAR_NAME="${REGISTERAR_NAME:-admin}"
ENROLLMENT_SECRET="${ENROLLMENT_SECRET:-adminpw}"
RUNNER_MODE="${ENVIRONMENT}"
FABRIC_CA_ADDRESS="${FABRIC_CA_ADDRESS:-localhost:7054}"
orgName="${ORG_NAME}"
domain="${SUB_DOMAIN}"
domainName="${SUB_DOMAIN}"
peerCount="${PEER_COUNT:-2}"
ordererCount="${ORDERER_COUNT:-0}"
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
if [[ -d "${BIN_DIR}" ]]; then
   case ":${PATH}:" in
      *":${BIN_DIR}:"*) ;;
      *) export PATH="${BIN_DIR}:${PATH}" ;;
   esac
fi

resolve_repo_path() {
   local path="$1"
   if [[ -z "${path}" ]]; then
      printf ""
      return
   fi
   if [[ "${path}" = /* ]]; then
      printf "%s" "${path}"
      return
   fi
   printf "%s/%s" "${REPO_ROOT}" "${path}"
}
