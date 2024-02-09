#!/bin/bash

. ./utils.sh
. ./global.sh

function createKeyCloakInstance(){
 
  infoln "Creating Keycloak Instance"
  set -e
  local hostname=${KeycloakHostName}
  local orgname=${ORG_NAME}
  cp ../templates/realm-test.json ../keycloak/realm-test.json
  cp ../templates/keycloak-docker-compose.yaml ../keycloak/keycloak-docker-compose.yaml
  sed -i -e "s|<KEY_CLOAK_HOST_NAME>|${hostname}|g" ../keycloak/keycloak-docker-compose.yaml
  sed -i -e "s/<KEY_CLOAK_HOST_NAME>/${hostname}/g" -e "s/<ORG_NAME>/${orgname}/g" ../keycloak/realm-test.json
  sed -i -e "s/<KEY_CLOAK_HOST_NAME>/${hostname}/g" ../keycloak/keycloak-docker-compose.yaml
  sudo mkdir -p ../keycloak/keycloakpostgres
  sudo chmod -R 777 ../keycloak/keycloakpostgres
  sudo chown -R 1001:1001 ../keycloak/keycloakpostgres
  docker-compose -f ../keycloak/keycloak-docker-compose.yaml up -d 
  set +e
}
if [[ ${KeycloakHostName} = " " || ${KeycloakHostName} = "" ]]; then 
   errorln " KeycloakHostName is not specified "
   exit 1
fi
if [[ ${ORG_NAME} = " " || ${ORG_NAME} = "" ]]; then 
   errorln " ORG_NAME is not specified "
   exit 1
fi
createKeyCloakInstance
