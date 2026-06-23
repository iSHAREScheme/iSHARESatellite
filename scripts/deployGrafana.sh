#!/bin/bash

set -euo pipefail

. ./utils.sh
. ./global.sh

function sed_escape(){
  printf '%s' "$1" | sed -e 's/[&|]/\\&/g'
}

function grafana_path(){
  local path="${GRAFANA_PUBLIC_PATH:-/logs}"
  path="/${path#/}"
  path="${path%/}"
  printf '%s' "${path}"
}

function ensure_secret(){
  local secret_file="../observability/grafana-client-secret"
  if [[ -n "${GRAFANA_KEYCLOAK_CLIENT_SECRET:-}" ]]; then
    printf '%s' "${GRAFANA_KEYCLOAK_CLIENT_SECRET}"
    return
  fi
  if [[ -s "${secret_file}" ]]; then
    cat "${secret_file}"
    return
  fi
  mkdir -p "$(dirname "${secret_file}")"
  openssl rand -hex 32 >"${secret_file}"
  chmod 600 "${secret_file}" || true
  cat "${secret_file}"
}

function keycloak_api_base(){
  local candidates=()
  local candidate status_code target_status_code

  if [[ "${TLS_MODE:-manual}" == "acme" ]]; then
    candidates+=("http://localhost:8080/auth")
    candidates+=("http://keycloak:8080/auth")
  else
    candidates+=("http://localhost:8080/auth")
    candidates+=("https://localhost:8443/auth")
    candidates+=("https://${KeycloakHostName}/auth")
  fi

  for _ in $(seq 1 120); do
    for candidate in "${candidates[@]}"; do
      status_code="$(curl -ksS -o /dev/null -w "%{http_code}" "${candidate}/realms/master" || true)"
      target_status_code="$(curl -ksS -o /dev/null -w "%{http_code}" "${candidate}/realms/${ORG_NAME}" || true)"
      if [[ "${status_code}" == "200" && "${target_status_code}" == "200" ]]; then
        printf '%s' "${candidate}"
        return
      fi
    done
    sleep 2
  done

  fatalln "Keycloak is not ready at any expected base URL (${candidates[*]})"
}

function upsert_keycloak_client(){
  local api_base="$1"
  local client_secret="$2"
  local grafana_public_path="$3"
  local client_id="${GRAFANA_KEYCLOAK_CLIENT_ID:-grafana}"
  local admin_user="${KEYCLOAK_ADMIN_USER:-admin}"
  local admin_password="${KEYCLOAK_ADMIN_PASSWORD:-admin}"
  local access_token
  local client_internal_id
  local redirect_uri="https://${UIHostName}${grafana_public_path}/login/generic_oauth"
  local ui_origin="https://${UIHostName}"
  local payload
  local status_code

  access_token="$(
    curl -ksS -X POST \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "grant_type=password" \
      -d "client_id=admin-cli" \
      -d "username=${admin_user}" \
      -d "password=${admin_password}" \
      "${api_base}/realms/master/protocol/openid-connect/token" \
      | jq -r '.access_token // empty'
  )"
  [[ -n "${access_token}" ]] || fatalln "Unable to obtain Keycloak admin token for Grafana client setup"

  client_internal_id="$(
    curl -ksS \
      -H "Authorization: Bearer ${access_token}" \
      "${api_base}/admin/realms/${ORG_NAME}/clients?clientId=${client_id}" \
      | jq -r '.[0].id // empty'
  )"

  payload="$(
    jq -n \
      --arg client_id "${client_id}" \
      --arg secret "${client_secret}" \
      --arg redirect_uri "${redirect_uri}" \
      --arg ui_origin "${ui_origin}" \
      '{
        clientId: $client_id,
        name: $client_id,
        enabled: true,
        protocol: "openid-connect",
        publicClient: false,
        clientAuthenticatorType: "client-secret",
        secret: $secret,
        standardFlowEnabled: true,
        directAccessGrantsEnabled: false,
        serviceAccountsEnabled: false,
        redirectUris: [$redirect_uri, ($redirect_uri + "/*")],
        webOrigins: [$ui_origin],
        attributes: {
          "post.logout.redirect.uris": ($ui_origin + "/*"),
          "oauth2.device.authorization.grant.enabled": "false",
          "oidc.ciba.grant.enabled": "false"
        },
        defaultClientScopes: ["web-origins", "role_list", "roles", "profile", "email"]
      }'
  )"

  if [[ -n "${client_internal_id}" ]]; then
    status_code="$(
      curl -ksS -o /tmp/grafana-keycloak-client-update.out -w "%{http_code}" \
        -X PUT \
        -H "Authorization: Bearer ${access_token}" \
        -H "Content-Type: application/json" \
        -d "${payload}" \
        "${api_base}/admin/realms/${ORG_NAME}/clients/${client_internal_id}"
    )"
    [[ "${status_code}" == "204" ]] || {
      cat /tmp/grafana-keycloak-client-update.out >&2 || true
      fatalln "Failed to update Keycloak Grafana client '${client_id}' (HTTP ${status_code})"
    }
    infoln "Updated Keycloak client '${client_id}' for Grafana"
  else
    status_code="$(
      curl -ksS -o /tmp/grafana-keycloak-client-create.out -w "%{http_code}" \
        -X POST \
        -H "Authorization: Bearer ${access_token}" \
        -H "Content-Type: application/json" \
        -d "${payload}" \
        "${api_base}/admin/realms/${ORG_NAME}/clients"
    )"
    [[ "${status_code}" == "201" || "${status_code}" == "204" || "${status_code}" == "409" ]] || {
      cat /tmp/grafana-keycloak-client-create.out >&2 || true
      fatalln "Failed to create Keycloak Grafana client '${client_id}' (HTTP ${status_code})"
    }
    infoln "Created Keycloak client '${client_id}' for Grafana"
  fi
}

function render_grafana_stack(){
  local dst="../observability"
  local grafana_public_path="$1"
  local client_secret="$2"
  local admin_password="${GRAFANA_ADMIN_PASSWORD:-}"
  local token_url
  local api_url
  local alloy_src

  if [[ -z "${admin_password}" ]]; then
    if [[ -s "${dst}/grafana-admin-password" ]]; then
      admin_password="$(cat "${dst}/grafana-admin-password")"
    else
      admin_password="$(openssl rand -base64 24 | tr -d '\n' | tr -d '/+=' | cut -c1-20)Aa1!"
      mkdir -p "${dst}"
      printf '%s' "${admin_password}" >"${dst}/grafana-admin-password"
      chmod 600 "${dst}/grafana-admin-password" || true
      warnln "GRAFANA_ADMIN_PASSWORD was not set; generated one in ${dst}/grafana-admin-password"
    fi
  fi

  if [[ "${TLS_MODE:-manual}" == "acme" ]]; then
    token_url="http://keycloak:8080/auth/realms/${ORG_NAME}/protocol/openid-connect/token"
    api_url="http://keycloak:8080/auth/realms/${ORG_NAME}/protocol/openid-connect/userinfo"
  else
    token_url="https://keycloak:8443/auth/realms/${ORG_NAME}/protocol/openid-connect/token"
    api_url="https://keycloak:8443/auth/realms/${ORG_NAME}/protocol/openid-connect/userinfo"
  fi

  mkdir -p "${dst}/configs" "${dst}/logs" "${dst}/loki-data" "${dst}/grafana-data"
  cp ../templates/grafana/loki.yaml "${dst}/configs/loki.yaml"
  alloy_src="$(resolve_repo_path "${GRAFANA_ALLOY_CONFIG:-}")"
  if [[ -n "${GRAFANA_ALLOY_CONFIG:-}" && -f "${alloy_src}" && "${alloy_src}" != "$(cd "${dst}/configs" && pwd)/config.alloy" ]]; then
    cp "${alloy_src}" "${dst}/configs/config.alloy"
  else
    cp ../templates/grafana/config.alloy "${dst}/configs/config.alloy"
  fi
  cp ../templates/grafana/datasources.yaml "${dst}/configs/datasources.yaml"
  cp ../templates/grafana/docker-compose.yaml "${dst}/docker-compose.yaml"
  {
    printf "GF_SECURITY_ADMIN_USER=%s\n" "${GRAFANA_ADMIN_USER:-admin}"
    printf "GF_SECURITY_ADMIN_PASSWORD=%s\n" "${admin_password}"
    printf "GF_AUTH_GENERIC_OAUTH_CLIENT_ID=%s\n" "${GRAFANA_KEYCLOAK_CLIENT_ID:-grafana}"
    printf "GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=%s\n" "${client_secret}"
  } >"${dst}/.grafana.env"
  chmod 600 "${dst}/.grafana.env" || true

  sed -i \
    -e "s|<GRAFANA_LOKI_PORT>|$(sed_escape "${GRAFANA_LOKI_PORT:-3100}")|g" \
    -e "s|<GRAFANA_PORT>|$(sed_escape "${GRAFANA_PORT:-3200}")|g" \
    -e "s|<GRAFANA_KEYCLOAK_TOKEN_URL>|$(sed_escape "${token_url}")|g" \
    -e "s|<GRAFANA_KEYCLOAK_API_URL>|$(sed_escape "${api_url}")|g" \
    -e "s|<GRAFANA_PUBLIC_PATH>|$(sed_escape "${grafana_public_path}")|g" \
    -e "s|<UIHostName>|$(sed_escape "${UIHostName}")|g" \
    -e "s|<KeycloakHostName>|$(sed_escape "${KeycloakHostName}")|g" \
    -e "s|<ORG_NAME>|$(sed_escape "${ORG_NAME}")|g" \
    "${dst}/docker-compose.yaml"

  sudo chown -R 10001:10001 "${dst}/loki-data" || true
  sudo chown -R 472:472 "${dst}/grafana-data" || true
}

function deploy_grafana(){
  local grafana_public_path
  local client_secret
  local api_base

  if [[ "${DEPLOY_GRAFANA:-false}" != "true" ]]; then
    infoln "DEPLOY_GRAFANA is not true; skipping deployGrafana.sh"
    exit 0
  fi

  grafana_public_path="$(grafana_path)"
  client_secret="$(ensure_secret)"
  api_base="$(keycloak_api_base)"
  upsert_keycloak_client "${api_base}" "${client_secret}" "${grafana_public_path}"
  render_grafana_stack "${grafana_public_path}" "${client_secret}"
  run_compose -f ../observability/docker-compose.yaml up -d --remove-orphans
  infoln "Grafana deployed at https://${UIHostName}${grafana_public_path}/"
}

deploy_grafana
