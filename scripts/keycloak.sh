#!/bin/bash

. ./utils.sh
. ./global.sh

function createKeyCloakInstance(){
 
  infoln "Creating Keycloak Instance"
  set -e
  local hostname=${KeycloakHostName}
  local uihost=${UIHostName}
  local orgname=${ORG_NAME}
  local keycloak_image="${KEYCLOAK_IMAGE:-isharefoundation/ishare-satellite-keycloak:v22.0.1}"
  local postgres_image="${POSTGRES_IMAGE:-isharefoundation/postgressql:v14-alpine}"
  cp ../templates/realm-test.json ../keycloak/realm-test.json
  cp ../templates/keycloak-docker-compose.yaml ../keycloak/keycloak-docker-compose.yaml
  sed -i \
    -e "s|<KEY_CLOAK_HOST_NAME>|${hostname}|g" \
    -e "s|<KEYCLOAK_IMAGE>|${keycloak_image}|g" \
    -e "s|<POSTGRES_IMAGE>|${postgres_image}|g" \
    ../keycloak/keycloak-docker-compose.yaml
  sed -i \
    -e "s/<KEY_CLOAK_HOST_NAME>/${hostname}/g" \
    -e "s/<UI_HOST_NAME>/${uihost}/g" \
    -e "s/<ORG_NAME>/${orgname}/g" \
    ../keycloak/realm-test.json
  docker-compose -f ../keycloak/keycloak-docker-compose.yaml up -d 
  set +e
}
if [[ ${KeycloakHostName} = " " || ${KeycloakHostName} = "" ]]; then 
   errorln " KeycloakHostName is not specified "
   exit 1
fi
if [[ ${UIHostName} = " " || ${UIHostName} = "" ]]; then
   errorln " UIHostName is not specified "
   exit 1
fi
if [[ ${ORG_NAME} = " " || ${ORG_NAME} = "" ]]; then 
   errorln " ORG_NAME is not specified "
   exit 1
fi
createKeyCloakInstance
