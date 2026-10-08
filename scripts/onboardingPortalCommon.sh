#!/bin/bash
# Shared helpers for the onboarding-portal deploy steps (sourced, not executed).

# Compute portal-Keycloak URLs + realm for the current ONBOARDING_KEYCLOAK_MODE.
# Exports OBP_KC_PUBLIC, OBP_KC_INTERNAL, OBP_KC_REALM.
obp_compute_kc_urls() {
  if [[ "${ONBOARDING_KEYCLOAK_MODE:-own}" == "shared" ]]; then
    # Co-deployed with the registry: portal operators live in the REGISTRY realm
    # (ORG_NAME), not a separate one. This is what lets the portal forward the
    # operator's token to the PR admin API (/api/*) - it is signed by the same
    # realm PR-MW validates against. One shared Keycloak (the portal image) serves
    # it at the registry KC hostname under /auth (matching keyCloakConfig.domain).
    OBP_KC_REALM="${ORG_NAME}"
    OBP_KC_PUBLIC="https://${KeycloakHostName}/auth"
    OBP_KC_INTERNAL="http://obp-keycloak:8080/auth"
  else
    # Standalone portal: its own realm on its own Keycloak.
    OBP_KC_REALM="onboarding-portal"
    OBP_KC_PUBLIC="https://${ONBOARDING_KC_HOSTNAME}"
    OBP_KC_INTERNAL="http://obp-keycloak:8080"
  fi
}

# GHCR login so the (private) onboarding-portal images can be pulled. No-op without a token.
obp_ghcr_login() {
  if [[ -n "${ONBOARDING_GHCR_TOKEN:-}" ]]; then
    infoln "Logging in to ghcr.io for onboarding-portal images"
    echo "${ONBOARDING_GHCR_TOKEN}" | docker login ghcr.io -u "${ONBOARDING_GHCR_USERNAME:-${ONBOARDING_GHCR_OWNER}}" --password-stdin
  else
    infoln "ONBOARDING_GHCR_TOKEN not set; assuming public images (set it if pulls are denied)."
  fi
}

# Extract the owner leaf certificate as the x5c value expected by PR-MW token
# validation. PR-MW validates every x5c entry as a client certificate, so sending
# the full chain can make the root CA entry fail validation. Participant payloads
# in the local cert tooling also store the leaf x5c only.
obp_pem_chain_leaf_to_x5c() {
  local cert_chain="$1"
  awk '
    /-----BEGIN CERTIFICATE-----/ && !done {
      in_cert = 1
      next
    }
    /-----END CERTIFICATE-----/ {
      if (in_cert) {
        done = 1
      }
      in_cert = 0
      next
    }
    in_cert && !done {
      gsub(/[[:space:]]/, "")
      cert = cert $0
    }
    END {
      printf "%s", cert
    }
  ' "${cert_chain}"
}

obp_owner_key_path() {
  if [[ -n "${ONBOARDING_OWNER_CERT_DIR:-}" && -f "${ONBOARDING_OWNER_CERT_DIR}/key.pem" ]]; then
    printf '%s' "${ONBOARDING_OWNER_CERT_DIR}/key.pem"
    return 0
  fi
  if [[ -f "../jwt-rsa/jwtRSA256-private.pem" ]]; then
    printf '%s' "../jwt-rsa/jwtRSA256-private.pem"
    return 0
  fi
  return 1
}

obp_owner_cert_chain_path() {
  if [[ -n "${ONBOARDING_OWNER_CERT_DIR:-}" && -f "${ONBOARDING_OWNER_CERT_DIR}/cert-chain.pem" ]]; then
    printf '%s' "${ONBOARDING_OWNER_CERT_DIR}/cert-chain.pem"
    return 0
  fi
  if [[ -f "../jwt-rsa/jwtRSA256-public.pem" ]]; then
    printf '%s' "../jwt-rsa/jwtRSA256-public.pem"
    return 0
  fi
  return 1
}

# Stage the satellite OWNER key into <dst>/backend/keys/sat-key.pem and echo the x5c value.
obp_stage_owner_creds() {
  local dst="$1"
  local owner_key owner_cert_chain
  mkdir -p "${dst}/backend/keys"
  owner_key="$(obp_owner_key_path)" || {
    errorln "Owner private key not found. Set ONBOARDING_OWNER_CERT_DIR with key.pem or provide jwt-rsa/jwtRSA256-private.pem."
    exit 1
  }
  owner_cert_chain="$(obp_owner_cert_chain_path)" || {
    errorln "Owner certificate chain not found. Set ONBOARDING_OWNER_CERT_DIR with cert-chain.pem or provide jwt-rsa/jwtRSA256-public.pem."
    exit 1
  }
  cp "${owner_key}" "${dst}/backend/keys/sat-key.pem"
  chmod 644 "${dst}/backend/keys/sat-key.pem" 2>/dev/null || true
  if [[ -n "${ONBOARDING_SATELLITE_X5C:-}" ]]; then
    printf '%s' "${ONBOARDING_SATELLITE_X5C}"
  else
    local x5c
    x5c="$(obp_pem_chain_leaf_to_x5c "${owner_cert_chain}")"
    if [[ -z "${x5c}" ]]; then
      errorln "No certificates found in ${owner_cert_chain}"
      exit 1
    fi
    printf '%s' "${x5c}"
  fi
}

obp_satellite_did() {
  local party_id="${ONBOARDING_SATELLITE_EORI:-${PARTY_ID}}"
  if [[ "${party_id}" == did:ishare:* ]]; then
    printf '%s' "${party_id}"
  else
    printf 'did:ishare:%s' "${party_id}"
  fi
}

# Render <dst>/.env from the template using .env.server values + computed KC URLs.
# $1 = dst dir, $2 = x5c value.
obp_render_env() {
  local dst="$1" x5c="$2"
  local admin_email="${ONBOARDING_ADMIN_EMAIL:-admin@example.com}"
  local admin_password="${ONBOARDING_ADMIN_PASSWORD:-change-me}"
  local satellite_did
  local smtp_from
  satellite_did="$(obp_satellite_did)"
  obp_compute_kc_urls
  smtp_from="${SMTP_FROM:-}"
  if [[ -z "${smtp_from}" ]]; then
    if [[ "${SMTP_USER:-}" == *@* ]]; then
      smtp_from="${SMTP_USER}"
    elif [[ "${DISPLAY_NAME:-}" == *@* ]]; then
      smtp_from="${DISPLAY_NAME}"
    else
      smtp_from="noreply@${SUB_DOMAIN}"
    fi
  fi
  # The PR admin API (/api/*) is the same co-located middleware service the portal
  # already reaches for the satellite. Enable it ONLY in shared mode, where the
  # operator's token is issued by the registry realm the PR validates against;
  # otherwise leave it blank so the registry-admin features stay hidden.
  local pr_api_base_url=""
  if [[ "${ONBOARDING_KEYCLOAK_MODE:-own}" == "shared" ]]; then
    pr_api_base_url="http://middleware-ishare_mw-1:21001"
  fi
  cp ../templates/onboarding-portal/onboarding-portal.env.template "${dst}/.env"
  sed -i \
    -e "s|<ONBOARDING_GHCR_OWNER>|${ONBOARDING_GHCR_OWNER}|g" \
    -e "s|<ONBOARDING_IMAGE_TAG>|${ONBOARDING_IMAGE_TAG:-latest}|g" \
    -e "s|<SATELLITE_VERSION>|${ONBOARDING_SATELLITE_VERSION:-3.0}|g" \
    -e "s|<SATELLITE_EORI>|${satellite_did}|g" \
    -e "s|<SATELLITE_PARTY_NAME>|${PARTY_NAME}|g" \
    -e "s|<SATELLITE_X5C>|${x5c}|g" \
    -e "s|<KC_PUBLIC_URL>|${OBP_KC_PUBLIC}|g" \
    -e "s|<KC_INTERNAL_URL>|${OBP_KC_INTERNAL}|g" \
    -e "s|<KC_REALM>|${OBP_KC_REALM}|g" \
    -e "s|<KC_ADMIN_USER>|${ONBOARDING_KC_ADMIN_USERNAME:-${KEYCLOAK_ADMIN_USERNAME:-${KEYCLOAK_ADMIN:-admin}}}|g" \
    -e "s|<KC_ADMIN_PASSWORD>|${ONBOARDING_KC_ADMIN_PASSWORD:-${KEYCLOAK_ADMIN_PASSWORD:-${KC_BOOTSTRAP_ADMIN_PASSWORD:-admin}}}|g" \
    -e "s|<KC_DB_PASSWORD>|${ONBOARDING_DB_PASSWORD:-keycloak}|g" \
    -e "s|<SMTP_HOST>|${SMTP_HOST:-}|g" \
    -e "s|<SMTP_PORT>|${SMTP_PORT:-587}|g" \
    -e "s|<SMTP_USER>|${SMTP_USER:-}|g" \
    -e "s|<SMTP_PASSWORD>|${SMTP_PASSWORD:-}|g" \
    -e "s|<SMTP_FROM>|${smtp_from}|g" \
    -e "s|<OBP_ADMIN_EMAIL>|${admin_email}|g" \
    -e "s|<OBP_ADMIN_PASSWORD>|${admin_password}|g" \
    -e "s|<ONBOARDING_UI_HOSTNAME>|${ONBOARDING_UI_HOSTNAME}|g" \
    -e "s|<PR_API_BASE_URL>|${pr_api_base_url}|g" \
    "${dst}/.env"
  # eHerkenning IdP env consumed by the portal Keycloak entrypoint (optional; blank = skipped).
  {
    echo "KEYCLOAK_IDP_NAME=${KEYCLOAK_IDP_NAME:-}"
    echo "KEYCLOAK_IDP_CLIENT=${KEYCLOAK_IDP_CLIENT:-}"
    echo "KEYCLOAK_IDP_SECRET=${KEYCLOAK_IDP_SECRET:-}"
    echo "EH_CHAIN_PEM=${EH_CHAIN_PEM:-}"
  } >> "${dst}/.env"
  # External VC issuer (optional). The portal polls the issuer's ObP /v1 API for a
  # party's credential offers. VC_ISSUER_API_KEY is the issuer's obp.api_key shared
  # bearer - without it the issuer answers 401 ("missing bearer token") and the
  # dashboard shows credentials as "unavailable". The base URL can instead be set
  # later via the admin Settings (stored in the portal DB), but the api key has no
  # Settings field, so it must be provided here to survive a redeploy.
  {
    echo "VC_ISSUER_BASE_URL=${ONBOARDING_VC_ISSUER_BASE_URL:-}"
    echo "VC_ISSUER_API_KEY=${ONBOARDING_VC_ISSUER_API_KEY:-}"
  } >> "${dst}/.env"
}

# Seed the onboarding portal settings row from the rendered .env. The backend
# creates the schema, but current images initialize satellite fields as empty
# strings, while the UI reads settings from SQLite instead of the env file.
obp_seed_settings_db() {
  local dst="$1"
  local db_container_path="${SQLITE_DB_NAME:-/app/db/onboarding}"
  if [[ "${db_container_path}" != /* ]]; then
    db_container_path="/app/${db_container_path}"
  fi

  local tmp_dir="/tmp/obp-settings-seed.$$"
  mkdir -p "${tmp_dir}"

  local copied="false"
  for _ in $(seq 1 30); do
    if docker cp "obp-backend:${db_container_path}" "${tmp_dir}/onboarding.sqlite" >/dev/null 2>&1; then
      copied="true"
      break
    fi
    sleep 1
  done

  if [[ "${copied}" != "true" ]]; then
    errorln "Could not copy onboarding SQLite DB from obp-backend:${db_container_path}"
    rm -rf "${tmp_dir}"
    return 1
  fi

  OBP_ENV_FILE="${dst}/.env" OBP_DB_FILE="${tmp_dir}/onboarding.sqlite" python3 - <<'PYSEED'
import os
import sqlite3
from pathlib import Path

env_file = Path(os.environ["OBP_ENV_FILE"])
db_file = Path(os.environ["OBP_DB_FILE"])

vals = {}
for raw in env_file.read_text().splitlines():
    line = raw.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    key, value = line.split("=", 1)
    vals[key] = value.strip().strip('"').strip("'")

updates = {
    "description": vals.get("NEXT_PUBLIC_DEFAULT_ASSOCIATION_NAME") or "",
    "registrar_id": vals.get("REGISTRAR_ID") or vals.get("SATELLITE_ISS") or "",
    "satellite_base_url": vals.get("SATELLITE_BASE_URL", ""),
    "satellite_iss": vals.get("SATELLITE_ISS", ""),
    "satellite_aud": vals.get("SATELLITE_AUD", ""),
    "satellite_version": vals.get("SATELLITE_VERSION", ""),
    "satellite_ep_creation_endpoint": vals.get("SATELLITE_EP_CREATION_ENDPOINT", ""),
    "satellite_parties_endpoint": vals.get("SATELLITE_PARTIES_ENDPOINT", "/parties"),
    "satellite_token_endpoint": vals.get("SATELLITE_TOKEN_ENDPOINT", ""),
    "satellite_token_scope": vals.get("SATELLITE_TOKEN_SCOPE", ""),
    "pr_api_base_url": vals.get("PR_API_BASE_URL", ""),
}

con = sqlite3.connect(db_file)
cur = con.cursor()
cur.execute("select count(*) from settings")
count = cur.fetchone()[0]
if count == 0:
    columns = ",".join(updates)
    placeholders = ",".join(["?"] * len(updates))
    cur.execute(f"insert into settings ({columns}) values ({placeholders})", list(updates.values()))
else:
    assignments = ", ".join(f"{key}=?" for key in updates)
    cur.execute(
        f"update settings set {assignments} where id=(select id from settings order by id limit 1)",
        list(updates.values()),
    )
con.commit()
con.close()
PYSEED

  docker cp "${tmp_dir}/onboarding.sqlite" "obp-backend:${db_container_path}" >/dev/null
  docker exec obp-backend sh -lc "chown appuser:appgroup '${db_container_path}' && chmod 0644 '${db_container_path}'" >/dev/null 2>&1 || true
  rm -rf "${tmp_dir}"
  infoln "Seeded onboarding portal settings in ${db_container_path}"
}
