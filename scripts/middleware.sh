. ./utils.sh
. ./global.sh
. ./fabric-var.sh

function ParseHLFMiddlewareConfig(){
    set -e
    cp ../templates/hlf-mw-config-template.yaml ../middleware/hlf-mw-config.yaml
    sed -i -e "s/<orgDomain>/${orgDomain}/g" -e "s/<orgName>/${orgName}/g" -e "s/<CHANNEL_NAME>/${CHANNEL_NAME}/g" -e "s/<CHAINCODE_NAME>/${CHAINCODE_NAME}/g" \
-e "s/<KeycloakHostName>/${KeycloakHostName}/g" ../middleware/hlf-mw-config.yaml

}
function ParseAPPMiddlewareConfig(){
    local PartyId=${PARTY_ID}
    local PartyName=${PARTY_NAME}
    set -e
    cp ../templates/app-mw-config-template.yaml ../middleware/app-mw-config.yaml
    sed -i -e "s/<orgDomain>/${orgDomain}/g" -e "s/<orgName>/${orgName}/g" -e "s/<CHANNEL_NAME>/${CHANNEL_NAME}/g" -e "s/<CHAINCODE_NAME>/${CHAINCODE_NAME}/g" \
-e "s/<KeycloakHostName>/${KeycloakHostName}/g" -e "s/<UIHostName>/${UIHostName}/g" -e "s/<PartyId>/${PartyId}/g" -e "s/<PartyName>/${PartyName}/g" ../middleware/app-mw-config.yaml
}

function ParseCompose(){
    set -e
   cp ../templates/docker-compose-mw-template.yaml ../middleware/docker-compose-mw.yaml
   
   cryptoPath=$(cd ../app/${RUNNER_MODE}/${orgName}/crypto && echo $(pwd))
   sed -i -e "s%<path-to-crypto>%${cryptoPath}%g" ../middleware/docker-compose-mw.yaml
}
function composeUp(){
    set -e
    docker-compose -f ../middleware/docker-compose-mw.yaml up -d
}

infoln "Starting middleware Parser"


if [[ ${UIHostName} = " " || ${UIHostName} = "" ]]; then 
   errorln " UIHostName is not specified "
   exit 1
fi

if [[ ${MiddlewareHostName} = " " || ${MiddlewareHostName} = "" ]]; then
   errorln " MiddlewareHostName is not specified "
   exit 1
fi

if [[ ${KeycloakHostName} = " " || ${KeycloakHostName} = "" ]]; then 
   errorln " KeycloakHostName is not specified "
   exit 1
fi

if [[ ${PARTY_ID} = " " || ${PARTY_ID} = "" ]]; then 
   errorln " PARTY_ID is not specified "
   exit 1
fi

if [[ ${PARTY_NAME} = " " || ${PARTY_NAME} = "" ]]; then 
   errorln " PARTY_NAME is not specified "
   exit 1
fi

ParseHLFMiddlewareConfig
ParseAPPMiddlewareConfig
ParseCompose
infoln "Bringing middleware up"
composeUp
