#!/bin/bash

. ./utils.sh
. ./global.sh

function deployUI(){
    local tls_mode="${TLS_MODE:-manual}"
    local ui_template="../templates/docker-compose-ui.yaml"
    local recreate_services="ishare_ui nginx-proxy"
    local grafana_public_path="${GRAFANA_PUBLIC_PATH:-/logs}"
    local grafana_port="${GRAFANA_PORT:-3200}"
    local grafana_nginx_http_block=""
    local grafana_nginx_server_block=""

    grafana_public_path="/${grafana_public_path#/}"
    grafana_public_path="${grafana_public_path%/}"
    if [[ "${DEPLOY_GRAFANA:-false}" == "true" ]]; then
      grafana_nginx_http_block='  # This is required to proxy Grafana Live WebSocket connections.
  map $http_upgrade $connection_upgrade {
      default upgrade;
      '"'"''"'"' close;
  }'
      grafana_nginx_server_block="$(cat <<EOF

    location = ${grafana_public_path} {
      return 301 ${grafana_public_path}/;
    }
    location ${grafana_public_path}/ {
      proxy_pass http://localhost:${grafana_port};
      proxy_set_header Host              \$host;
      proxy_set_header X-Real-IP         \$remote_addr;
      proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto \$scheme;
      proxy_set_header X-Forwarded-Host  \$host;
      proxy_set_header X-Forwarded-Port  \$server_port;
    }
    location ${grafana_public_path}/api/live/ {
      proxy_http_version 1.1;
      proxy_set_header Upgrade           \$http_upgrade;
      proxy_set_header Connection        \$connection_upgrade;
      proxy_set_header Host              \$host;
      proxy_set_header X-Real-IP         \$remote_addr;
      proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto \$scheme;
      proxy_set_header X-Forwarded-Host  \$host;
      proxy_set_header X-Forwarded-Port  \$server_port;
      proxy_pass http://localhost:${grafana_port};
    }
EOF
)"
    fi

    mkdir -p ../ui
    if [[ "${tls_mode,,}" == "manual" ]]; then
      cp ../templates/nginx-template.conf ../ui/nginx.conf
      sed -i \
        -e "s/<UIHostName>/${UIHostName}/g" \
        -e "s/<MiddlewareHostName>/${MiddlewareHostName}/g" \
        -e "s/<KeycloakHostName>/${KeycloakHostName}/g" \
        ../ui/nginx.conf
      awk -v http_block="${grafana_nginx_http_block}" -v server_block="${grafana_nginx_server_block}" '
        {
          if ($0 ~ /<GRAFANA_NGINX_HTTP_BLOCK>/) {
            if (length(http_block) > 0) {
              printf "%s\n", http_block
            }
            next
          }
          if ($0 ~ /<GRAFANA_NGINX_SERVER_BLOCK>/) {
            if (length(server_block) > 0) {
              printf "%s\n", server_block
            }
            next
          }
          print
        }' ../ui/nginx.conf > ../ui/nginx.conf.tmp
      mv ../ui/nginx.conf.tmp ../ui/nginx.conf
      ui_template="../templates/docker-compose-ui.yaml"
      recreate_services="ishare_ui nginx-proxy"
    else
      ui_template="../templates/docker-compose-ui-acme.yaml"
      recreate_services="ishare_ui"
    fi

    cp "${ui_template}" ../ui/docker-compose-ui.yaml
    sed -i -e "s/<UIHostName>/${UIHostName}/g" -e "s/<MiddlewareHostName>/${MiddlewareHostName}/g" -e "s/<KeycloakHostName>/${KeycloakHostName}/g" -e "s/<ORG_NAME>/${ORG_NAME}/g" ../ui/docker-compose-ui.yaml

    run_compose -f ../ui/docker-compose-ui.yaml up -d --remove-orphans
    # Ensure updated env values are applied on redeploy/resume runs.
    run_compose -f ../ui/docker-compose-ui.yaml up -d --force-recreate --remove-orphans ${recreate_services}
    infoln "deployment finished, use below command to check the status, if the status is showing Exited contact your support ...  "
    infoln "docker compose -f ../ui/docker-compose-ui.yaml ps"
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
