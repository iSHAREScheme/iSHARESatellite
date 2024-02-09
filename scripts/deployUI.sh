#!/bin/bash

. ./utils.sh
. ./global.sh

function deployUI(){

    mkdir -p ../ui
    cp ../templates/nginx-template.conf ../ui/nginx.conf
    sed -i -e "s/<UIHostName>/${UIHostName}/g" -e "s/<MiddlewareHostName>/${MiddlewareHostName}/g" ../ui/nginx.conf

    cp ../templates/docker-compose-ui.yaml ../ui/docker-compose-ui.yaml
    sed -i -e "s/<UIHostName>/${UIHostName}/g" -e "s/<MiddlewareHostName>/${MiddlewareHostName}/g" -e "s/<KeycloakHostName>/${KeycloakHostName}/g" -e "s/<ORG_NAME>/${ORG_NAME}/g" ../ui/docker-compose-ui.yaml

    docker-compose -f ../ui/docker-compose-ui.yaml up -d
    infoln "deployment finished, use below command to check the status, if the status is showing Exited contact your support ...  "
    infoln "docker-compose -f ../ui/docker-compose-ui.yaml ps"
}

if [[ ${UIHostName} = " " || ${UIHostName} = "" ]]; then 
   errorln " UIHostName is not specified "
   exit 1
fi

if [[ ${MiddliewareHostName} = " " || ${MiddlewareHostName} = "" ]]; then 
   errorln " MiddlewareHostName is not specified "
   exit 1
fi

if [[ ${KeycloakHostName} = " " || ${KeycloakHostName} = "" ]]; then 
   errorln " KeycloakHostName is not specified "
   exit 1
fi

if [[ ${ORG_NAME} = " " || ${ORG_NAME} = "" ]]; then 
   errorln " ORG_NAME is not specified "
   exit 1
fi
deployUI
