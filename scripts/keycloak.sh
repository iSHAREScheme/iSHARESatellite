#!/bin/bash

. ./utils.sh
. ./global.sh

function createKeyCloakInstance(){
 
  infoln "Creating Keycloak Instance"
  set -e
  local hostname=${KeycloakHostName}
  # Check the length of KeycloakHostName
  if [ ${#hostname} -gt 35 ]; then
    errorln "KeycloakHostName exceeds 35 characters in length."
    exit 1
  fi  
  cp ../templates/realm-test.json ../keycloak/realm-test.json
  sed -i -e "s/<KEY_CLOAK_HOST_NAME>/${hostname}/g" -e "s/<UIHostName>/${UIHostName}/g" ../keycloak/realm-test.json
  sed -i -e "s/<KEY_CLOAK_HOST_NAME>/${hostname}/g" ../keycloak/keycloak-docker-compose.yaml
  docker-compose -f ../keycloak/keycloak-docker-compose.yaml up -d 
  set +e
}
if [[ ${KeycloakHostName} = " " || ${KeycloakHostName} = "" ]]; then 
   errorln " KeycloakHostName is not specified "
   exit 1
fi
if [[ ${UIHostName} = " " || ${UIHostName} = "" ]]; then 
   errorln " KeycloakHostName is not specified "
   exit 1
fi
createKeyCloakInstance
