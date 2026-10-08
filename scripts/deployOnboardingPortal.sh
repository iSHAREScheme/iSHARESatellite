#!/bin/bash

. ./utils.sh
. ./global.sh
. ./onboardingPortalCommon.sh

# Deploys the onboarding portal APP (backend + frontend) alongside the participant registry,
# from prebuilt GHCR images, reusing the registry OWNER iSHARE identity for M2M auth.
#
# Keycloak:
#   - own    : also brings up the portal's own Keycloak (+ postgres) via the override file.
#   - shared : the shared Keycloak was already deployed by deployOnboardingPortalKeycloak.sh
#              (the portal image serving both realms at ${KeycloakHostName}); only the app runs here.
#
function deployOnboardingPortal(){
  local kc_mode="${ONBOARDING_KEYCLOAK_MODE:-own}"
  infoln "Deploying onboarding portal app (Keycloak mode: ${kc_mode})"
  set -e

  local dst=../onboarding-portal
  local tls_mode="${TLS_MODE:-manual}"

  if [[ -z "${ONBOARDING_IMAGE_REGISTRY:-}" && -z "${ONBOARDING_GHCR_OWNER:-}" ]]; then
    errorln "ONBOARDING_IMAGE_REGISTRY or ONBOARDING_GHCR_OWNER is required"; exit 1
  fi
  if [[ -z "${ONBOARDING_UI_HOSTNAME:-}" ]]; then errorln "ONBOARDING_UI_HOSTNAME is required"; exit 1; fi
  if [[ "${kc_mode}" == "own" && -z "${ONBOARDING_KC_HOSTNAME:-}" ]]; then
    errorln "ONBOARDING_KC_HOSTNAME is required when ONBOARDING_KEYCLOAK_MODE=own"; exit 1
  fi

  # Render compose + .env + owner creds (idempotent; in shared mode the .env was already
  # rendered by deployOnboardingPortalKeycloak.sh, re-rendering is harmless).
  cp ../templates/onboarding-portal/docker-compose.yaml "${dst}/docker-compose.yaml"
  cp ../templates/onboarding-portal/docker-compose.own-keycloak.yaml "${dst}/docker-compose.own-keycloak.yaml"
  local x5c; x5c="$(obp_stage_owner_creds "${dst}")"
  obp_render_env "${dst}" "${x5c}"

  obp_ghcr_login
  ( cd "${dst}"
    if [[ "${kc_mode}" == "own" ]]; then
      docker-compose --env-file .env -f docker-compose.yaml -f docker-compose.own-keycloak.yaml pull
      docker-compose --env-file .env -f docker-compose.yaml -f docker-compose.own-keycloak.yaml up -d --remove-orphans
    else
      docker-compose --env-file .env -f docker-compose.yaml pull
      docker-compose --env-file .env -f docker-compose.yaml up -d --remove-orphans
    fi
  )

  obp_seed_settings_db "${dst}"

  if [[ "${tls_mode,,}" == "acme" ]]; then
    addOnboardingCaddyRoutes "${kc_mode}"
  else
    infoln "TLS_MODE=manual: add nginx server blocks for ${ONBOARDING_UI_HOSTNAME} -> :3000 (and, in own mode, ${ONBOARDING_KC_HOSTNAME:-<portal-kc>} -> :8088) to your reverse proxy."
  fi

  infoln "Onboarding portal deployed. UI: https://${ONBOARDING_UI_HOSTNAME}"
  set +e
}

# Append portal routes to the registry's ACME (Caddy) edge. In shared mode the portal uses
# ${KeycloakHostName} (already routed by the registry edge), so only the UI route is added.
function addOnboardingCaddyRoutes(){
  local kc_mode="$1"
  local caddyfile=../edge/Caddyfile
  if [[ ! -f "${caddyfile}" ]]; then
    infoln "edge Caddyfile not found at ${caddyfile}; add the portal route manually"
    return 0
  fi
  if grep -q "# onboarding-portal routes" "${caddyfile}"; then
    infoln "Onboarding portal Caddy routes already present; leaving as-is"
    return 0
  fi
  {
    echo ""
    echo "# onboarding-portal routes"
    echo "${ONBOARDING_UI_HOSTNAME} {"
    echo "    reverse_proxy localhost:3000"
    echo "}"
    if [[ "${kc_mode}" == "own" ]]; then
      echo "${ONBOARDING_KC_HOSTNAME} {"
      echo "    reverse_proxy localhost:8088"
      echo "}"
    fi
  } >> "${caddyfile}"
  infoln "Appended onboarding-portal routes to ${caddyfile}; reloading Caddy"
  docker exec edge-acme caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile 2>/dev/null \
    || docker restart edge-acme >/dev/null 2>&1 || true
}

deployOnboardingPortal
