#!/bin/bash

. ./utils.sh
. ./global.sh

function deployUI(){
    local tls_mode="${TLS_MODE:-manual}"
    local ui_template="../templates/docker-compose-ui.yaml"
    local recreate_services="ishare_ui nginx-proxy"

    mkdir -p ../ui
    if [[ "${tls_mode,,}" == "manual" ]]; then
      cp ../templates/nginx-template.conf ../ui/nginx.conf
      sed -i \
        -e "s/<UIHostName>/${UIHostName}/g" \
        -e "s/<MiddlewareHostName>/${MiddlewareHostName}/g" \
        -e "s/<KeycloakHostName>/${KeycloakHostName}/g" \
        ../ui/nginx.conf
      ui_template="../templates/docker-compose-ui.yaml"
      recreate_services="ishare_ui nginx-proxy"
    else
      ui_template="../templates/docker-compose-ui-acme.yaml"
      recreate_services="ishare_ui"
    fi

    cp "${ui_template}" ../ui/docker-compose-ui.yaml
    sed -i -e "s/<UIHostName>/${UIHostName}/g" -e "s/<MiddlewareHostName>/${MiddlewareHostName}/g" -e "s/<KeycloakHostName>/${KeycloakHostName}/g" -e "s/<ORG_NAME>/${ORG_NAME}/g" ../ui/docker-compose-ui.yaml

    docker-compose -f ../ui/docker-compose-ui.yaml up -d --remove-orphans
    # Ensure updated env values are applied on redeploy/resume runs.
    docker-compose -f ../ui/docker-compose-ui.yaml up -d --force-recreate --remove-orphans ${recreate_services}
    infoln "deployment finished, use below command to check the status, if the status is showing Exited contact your support ...  "
    infoln "docker-compose -f ../ui/docker-compose-ui.yaml ps"
}

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

if [[ ${ORG_NAME} = " " || ${ORG_NAME} = "" ]]; then 
   errorln " ORG_NAME is not specified "
   exit 1
fi
deployUI
