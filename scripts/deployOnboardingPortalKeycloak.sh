#!/bin/bash

. ./utils.sh
. ./global.sh
. ./onboardingPortalCommon.sh

# SHARED Keycloak deploy - runs in place of keycloak.sh when ONBOARDING_KEYCLOAK_MODE=shared.
# Builds a shared Keycloak image FROM the onboarding-portal Keycloak image (so all its custom
# wiring/providers/entrypoint stay intact), grafts on the registry realm (<ORG_NAME>) + myTheme,
# re-bakes at /auth, and runs it as THE Keycloak for both the satellite and the portal at
# ${KeycloakHostName}:8080 (the host port the registry edge already routes to). The registry's
# own keycloak.sh is NOT run in this mode.

function deploySharedPortalKeycloak(){
  infoln "Deploying SHARED Keycloak: onboarding-portal image + registry realm '${ORG_NAME}' + myTheme"
  set -e
  local dst=../onboarding-portal
  local bctx=../keycloak/shared-build
  local smtp_from="${SMTP_USER:-}"
  if [[ -z "${smtp_from}" || "${smtp_from}" != *@* ]]; then
    smtp_from="noreply@${SUB_DOMAIN}"
  fi

  obp_ghcr_login

  # Build context: Dockerfile + rendered registry realm.
  rm -rf "${bctx}"; mkdir -p "${bctx}"
  cp ../templates/onboarding-portal/keycloak-shared/Dockerfile "${bctx}/Dockerfile"
  if [[ -d ../keycloak/myTheme ]]; then
    cp -R ../keycloak/myTheme "${bctx}/myTheme"
  fi
  cp ../templates/realm-test.json "${bctx}/realm-test.json"
  sed -i \
    -e "s/<KEY_CLOAK_HOST_NAME>/${KeycloakHostName}/g" \
    -e "s/<ORG_NAME>/${ORG_NAME}/g" \
    -e "s/<UI_HOST_NAME>/${UIHostName}/g" \
    -e "s/<ONBOARDING_UI_HOST_NAME>/${ONBOARDING_UI_HOSTNAME}/g" \
    -e "s|<SMTP_HOST>|${SMTP_HOST:-}|g" \
    -e "s|<SMTP_PORT>|${SMTP_PORT:-}|g" \
    -e "s|<SMTP_USER>|${SMTP_USER:-}|g" \
    -e "s|<SMTP_PASSWORD>|${SMTP_PASSWORD:-}|g" \
    -e "s|<SMTP_FROM>|${smtp_from}|g" \
    -e "s|<OBP_ADMIN_EMAIL>|${ONBOARDING_ADMIN_EMAIL:-admin@example.com}|g" \
    -e "s|<OBP_ADMIN_PASSWORD>|${ONBOARDING_ADMIN_PASSWORD:-change-me}|g" \
    "${bctx}/realm-test.json"

  # Render the portal .env (consumed by the shared KC now and the portal app later).
  local x5c; x5c="$(obp_stage_owner_creds "${dst}")"
  obp_render_env "${dst}" "${x5c}"

  # Write the shared KC compose at the registry keycloak path so install-server's later
  # "Rendered keycloak compose" assertion still passes.
  mkdir -p ../keycloak
  cp ../templates/onboarding-portal/docker-compose.shared-keycloak.yaml ../keycloak/keycloak-docker-compose.yaml
  sed -i -e "s|<KEY_CLOAK_HOST_NAME>|${KeycloakHostName}|g" ../keycloak/keycloak-docker-compose.yaml

  # Build (pulls the private portal KC base image via the GHCR login above) + run.
  ( cd ../keycloak
    docker-compose --env-file ../onboarding-portal/.env -f keycloak-docker-compose.yaml build
    docker-compose --env-file ../onboarding-portal/.env -f keycloak-docker-compose.yaml up -d
  )

  infoln "Shared Keycloak up at https://${KeycloakHostName}/auth (realms: ${ORG_NAME} + onboarding-portal)"
  set +e
}

deploySharedPortalKeycloak
