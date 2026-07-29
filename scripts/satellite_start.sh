#!/bin/bash

echo "Starting all docker containers... please wait..."
echo "Starting up Fabric ca"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SAT_HOME="${SAT_HOME:-$(dirname "$SCRIPT_DIR")}"
export SAT_HOME
export PATH=$PATH:/usr/local/bin/

docker compose -f $SAT_HOME/hlf/<env>/<orgname>/fabric-ca/docker-compose-fabric-ca.yaml up -d
sleep 15
echo "Starting up peers"
docker compose -f $SAT_HOME/hlf/<env>/<orgname>/peers/docker-compose-hlf.yaml up -d
sleep 15
echo "Starting up chaincode"
docker compose -f $SAT_HOME/chaincode/cc-docker-compose-template.yaml up -d
sleep 15
echo "Starting up keycloak"
docker compose -f $SAT_HOME/keycloak/keycloak-docker-compose.yaml up -d
sleep 15
echo "Starting up middleware"
docker compose -f $SAT_HOME/middleware/docker-compose-mw.yaml up -d
sleep 30
echo "Starting up explorer"
docker compose -f $SAT_HOME/explorer/explorer-docker-compose.yaml up -d
sleep 20
echo "Starting up UI"
docker compose -f $SAT_HOME/ui/docker-compose-ui.yaml up -d
sleep 10

echo "Your satellite is up"




