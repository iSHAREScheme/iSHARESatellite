. ./utils.sh
. ./global.sh
. ./fabric-var.sh

function ParseHLFMiddlewareConfig(){
    set -e
    cp ../templates/hlf-mw-config-template.yaml ../middleware/hlf-mw-config.yaml
    sed -i -e "s/<orgDomain>/${orgDomain}/g" -e "s/<orgName>/${orgName}/g" -e "s/<CHANNEL_NAME>/${CHANNEL_NAME}/g" -e "s/<CHAINCODE_NAME>/${CHAINCODE_NAME}/g" \
-e "s/<KeycloakHostName>/${KeycloakHostName}/g" ../middleware/hlf-mw-config.yaml
    if [[ "${PEER_COUNT:-2}" == "1" ]]; then
      awk '
      BEGIN {skip_channels_peer1=0; skip_peers_peer1=0}
      {
        if ($0 ~ /^      peer1\./) { skip_channels_peer1=1; next }
        if (skip_channels_peer1==1) {
          if ($0 ~ /^    policies:/) { skip_channels_peer1=0; print $0; next }
          next
        }
        if ($0 ~ /^  peer1\./) { skip_peers_peer1=1; next }
        if (skip_peers_peer1==1) {
          if ($0 ~ /^certificateAuthorities:/) { skip_peers_peer1=0; print $0; next }
          next
        }
        if ($0 ~ /^    - peer1\./) { next }
        print $0
      }' ../middleware/hlf-mw-config.yaml > ../middleware/hlf-mw-config.yaml.tmp
      mv ../middleware/hlf-mw-config.yaml.tmp ../middleware/hlf-mw-config.yaml
    fi

    local active_peer_tls_ca="../hlf/${RUNNER_MODE}/${orgName}/crypto/peers/peer0.${orgDomain}/tls/server/ca.pem"
    local app_admin_tls_ca="../app/${RUNNER_MODE}/${orgName}/crypto/peerOrganizations/${orgDomain}/users/Admin@${orgDomain}/msp/tlscacerts/tlscacert.pem"
    if [[ -f "${active_peer_tls_ca}" ]]; then
      mkdir -p "$(dirname "${app_admin_tls_ca}")"
      cp "${active_peer_tls_ca}" "${app_admin_tls_ca}"
      chmod 644 "${app_admin_tls_ca}" || true
    fi

    # HLF middleware runs as appuser(1000); ensure it can read admin key material.
    local app_admin_msp_dir="../app/${RUNNER_MODE}/${orgName}/crypto/peerOrganizations/${orgDomain}/users/Admin@${orgDomain}/msp"
    if [[ -d "${app_admin_msp_dir}/keystore" ]]; then
      sudo chown -R 1000:1000 "${app_admin_msp_dir}/keystore" || true
      sudo chmod 700 "${app_admin_msp_dir}/keystore" || true
      sudo find "${app_admin_msp_dir}/keystore" -type f -exec chmod 600 {} \; || true
    fi
    sudo find "${app_admin_msp_dir}/signcerts" "${app_admin_msp_dir}/cacerts" "${app_admin_msp_dir}/tlscacerts" -type f -exec chmod 644 {} \; 2>/dev/null || true
}

function ParseAPPMiddlewareConfig(){
    local PartyId=${PARTY_ID}
    local PartyName=${PARTY_NAME}
    local DisplayName="${DISPLAY_NAME}"
    set -e
    cp ../templates/app-mw-config-template.yaml ../middleware/app-mw-config.yaml
    sed -i -e "s/<orgDomain>/${orgDomain}/g" -e "s/<orgName>/${orgName}/g" -e "s/<CHANNEL_NAME>/${CHANNEL_NAME}/g" -e "s/<CHAINCODE_NAME>/${CHAINCODE_NAME}/g" \
-e "s/<KeycloakHostName>/${KeycloakHostName}/g" -e "s/<UIHostName>/${UIHostName}/g" -e "s/<PartyId>/${PartyId}/g" -e "s/<PartyName>/${PartyName}/g" ../middleware/app-mw-config.yaml
    sed -i -e "s/<SMTP_PASSWORD>/${SMTP_PASSWORD}/g" -e "s/<SMTP_PORT>/${SMTP_PORT}/g" -e "s/<SMTP_HOST>/${SMTP_HOST}/g" -e "s/<SMTP_USER>/${SMTP_USER}/g" \
-e "s/<DISPLAY_NAME>/${DisplayName}/g" ../middleware/app-mw-config.yaml
   if [[ "$ENVIRONMENT" == "uat" || "$ENVIRONMENT" == "test" || "$ENVIRONMENT" == "prod" ]]; then
        if [[ "$ENVIRONMENT" == "test" ]]; then
            ENVIRONMENT="uat"
        fi
        sed -i -e "s/<ENVIRONMENT>/${ENVIRONMENT}/g" ../middleware/app-mw-config.yaml
    else
        echo "Invalid mode provided. Using default mode."
        MODE="default"
        sed -i -e "s/<ENVIRONMENT>/${ENVIRONMENT}/g" ../middleware/app-mw-config.yaml
    fi
}

function ParseCompose(){
    set -e
   local tls_mode="${TLS_MODE:-manual}"
   local tls_volume_line="      - ../ssl/tls.crt:/etc/ssl/local/tls.crt:ro"
   local tls_env_line="      - SSL_CERT_FILE=/etc/ssl/local/tls.crt"

   cp ../templates/docker-compose-mw-template.yaml ../middleware/docker-compose-mw.yaml

   cryptoPath=$(cd ../app/${RUNNER_MODE}/${orgName}/crypto && echo $(pwd))
   if [[ "${tls_mode,,}" == "acme" ]]; then
     tls_volume_line=""
     tls_env_line=""
   fi
   sed -i \
     -e "s%<path-to-crypto>%${cryptoPath}%g" \
     -e "s%<OPTIONAL_TLS_CERT_VOLUME>%${tls_volume_line}%g" \
     -e "s%<OPTIONAL_SSL_CERT_ENV>%${tls_env_line}%g" \
     ../middleware/docker-compose-mw.yaml

   # Reset clearly broken postgresdata dir (non-empty but no PG_VERSION).
   if [[ -d ../middleware/postgresdata ]] && [[ ! -f ../middleware/postgresdata/PG_VERSION ]]; then
     if find ../middleware/postgresdata -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
       local ts
       ts=$(date +%Y%m%d-%H%M%S)
       warnln "Detected incomplete postgresdata dir, backing up to ../middleware/postgresdata.bak-${ts}"
       sudo mv ../middleware/postgresdata "../middleware/postgresdata.bak-${ts}"
     fi
   fi

   sudo mkdir -p ../middleware/postgresdata
   sudo chmod -R 700 ../middleware/postgresdata
   sudo chown -R 1001:1001 ../middleware/postgresdata
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
