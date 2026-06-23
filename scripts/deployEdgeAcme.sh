#!/bin/bash

set -euo pipefail

. ./utils.sh
. ./global.sh

function resolve_path_local() {
  local path="$1"
  if [[ "${path}" = /* ]]; then
    printf "%s" "${path}"
    return
  fi
  printf "%s/%s" "${REPO_ROOT}" "${path}"
}

function probe_https_host() {
  local host="$1"
  local status_code=""
  local curl_stderr=""
  local attempt=0
  local interval_seconds="${ACME_PROBE_INTERVAL_SECONDS:-5}"
  local timeout_seconds="${ACME_PROBE_TIMEOUT_SECONDS:-420}"
  local deadline
  local stderr_file=""

  deadline=$(( $(date +%s) + timeout_seconds ))

  while [[ $(date +%s) -lt ${deadline} ]]; do
    attempt=$((attempt + 1))
    stderr_file="$(mktemp)"
    status_code="$(curl --connect-timeout 5 --max-time 15 -sS -o /dev/null -w "%{http_code}" "https://${host}/" 2>"${stderr_file}" || true)"
    curl_stderr="$(tr '\n' ' ' <"${stderr_file}" | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"
    rm -f "${stderr_file}"
    stderr_file=""

    if [[ "${status_code}" =~ ^[1-5][0-9][0-9]$ ]]; then
      infoln "HTTPS probe succeeded for ${host} (HTTP ${status_code}) after ${attempt} attempt(s)"
      return 0
    fi

    if (( attempt == 1 || attempt % 6 == 0 )); then
      warnln "HTTPS probe still waiting for ${host}; last curl result: HTTP ${status_code:-000}${curl_stderr:+, ${curl_stderr}}"
    fi

    sleep "${interval_seconds}"
  done

  errorln "HTTPS probe failed for ${host} after ${timeout_seconds}s. Last curl result: HTTP ${status_code:-000}${curl_stderr:+, ${curl_stderr}}"
  return 1
}

function deploy_edge_acme() {
  local tls_mode_normalized="${TLS_MODE:-manual}"
  local acme_email="${ACME_EMAIL:-}"
  local acme_staging="${ACME_STAGING:-false}"
  local acme_ca_server="${ACME_CA_SERVER:-}"
  local acme_http_port="${ACME_HTTP_PORT:-80}"
  local acme_https_port="${ACME_HTTPS_PORT:-443}"
  local acme_state_path="${ACME_STORAGE_PATH:-.local-state/acme}"
  local acme_state_dir
  local acme_ca_line=""
  local escaped_ca_line
  local grafana_public_path="${GRAFANA_PUBLIC_PATH:-/logs}"
  local grafana_port="${GRAFANA_PORT:-3200}"
  local grafana_caddy_routes=""

  tls_mode_normalized="${tls_mode_normalized,,}"
  grafana_public_path="/${grafana_public_path#/}"
  grafana_public_path="${grafana_public_path%/}"
  if [[ "${tls_mode_normalized}" != "acme" ]]; then
    infoln "TLS_MODE is not acme; skipping deployEdgeAcme.sh"
    exit 0
  fi

  if [[ -z "${acme_email}" ]]; then
    errorln "ACME_EMAIL is required for TLS_MODE=acme"
    exit 1
  fi

  if [[ "${acme_http_port}" != "80" || "${acme_https_port}" != "443" ]]; then
    errorln "ACME currently supports fixed ports only: ACME_HTTP_PORT=80 and ACME_HTTPS_PORT=443."
    exit 1
  fi

  if [[ -n "${acme_ca_server}" ]]; then
    acme_ca_line="  acme_ca ${acme_ca_server}"
  elif [[ "${acme_staging,,}" == "true" ]]; then
    acme_ca_line="  acme_ca https://acme-staging-v02.api.letsencrypt.org/directory"
  fi

  mkdir -p ../edge
  acme_state_dir="$(resolve_path_local "${acme_state_path}")"
  mkdir -p "${acme_state_dir}/data" "${acme_state_dir}/config"
  chmod 700 "${acme_state_dir}" "${acme_state_dir}/data" "${acme_state_dir}/config" || true

  cp ../templates/docker-compose-edge-acme-template.yaml ../edge/docker-compose-edge-acme.yaml
  sed -i \
    -e "s%<ACME_STATE_DIR>%${acme_state_dir}%g" \
    ../edge/docker-compose-edge-acme.yaml

  cp ../templates/caddy-acme-template.Caddyfile ../edge/Caddyfile
  if [[ "${DEPLOY_GRAFANA:-false}" == "true" ]]; then
    grafana_caddy_routes="$(cat <<EOF
  @grafana_root path ${grafana_public_path}
  redir @grafana_root ${grafana_public_path}/ 308

  handle ${grafana_public_path}/api/live/* {
    reverse_proxy 127.0.0.1:${grafana_port}
  }

  handle ${grafana_public_path}/* {
    reverse_proxy 127.0.0.1:${grafana_port}
  }
EOF
)"
  fi
  escaped_ca_line="$(printf "%s" "${acme_ca_line}" | sed 's/[\\/&]/\\&/g')"
  sed -i \
    -e "s/<ACME_EMAIL>/${acme_email}/g" \
    -e "s/<UIHostName>/${UIHostName}/g" \
    -e "s/<MiddlewareHostName>/${MiddlewareHostName}/g" \
    -e "s/<KeycloakHostName>/${KeycloakHostName}/g" \
    -e "s/<ACME_CA_LINE>/${escaped_ca_line}/g" \
    ../edge/Caddyfile
  awk -v routes="${grafana_caddy_routes}" '
    {
      if ($0 ~ /<GRAFANA_CADDY_ROUTES>/) {
        if (length(routes) > 0) {
          printf "%s\n", routes
        }
        next
      }
      print
    }' ../edge/Caddyfile > ../edge/Caddyfile.tmp
  mv ../edge/Caddyfile.tmp ../edge/Caddyfile

  run_compose -f ../edge/docker-compose-edge-acme.yaml up -d --force-recreate --remove-orphans

  probe_https_host "${UIHostName}"
  probe_https_host "${MiddlewareHostName}"
  probe_https_host "${KeycloakHostName}"

  infoln "ACME edge deployment finished."
}

if [[ ${UIHostName:-} = " " || ${UIHostName:-} = "" ]]; then
  errorln "UIHostName is not specified"
  exit 1
fi

if [[ ${MiddlewareHostName:-} = " " || ${MiddlewareHostName:-} = "" ]]; then
  errorln "MiddlewareHostName is not specified"
  exit 1
fi

if [[ ${KeycloakHostName:-} = " " || ${KeycloakHostName:-} = "" ]]; then
  errorln "KeycloakHostName is not specified"
  exit 1
fi

deploy_edge_acme
