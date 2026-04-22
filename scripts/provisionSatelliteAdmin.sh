#!/bin/bash

set -euo pipefail

. ./utils.sh
. ./global.sh

KEYCLOAK_BASE_URL="${KEYCLOAK_BASE_URL:-https://${KeycloakHostName}}"
KEYCLOAK_PATH_PREFIX="${KEYCLOAK_PATH_PREFIX:-/auth}"
KEYCLOAK_ADMIN_USER="${KEYCLOAK_ADMIN_USER:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin}"
SATELLITE_ADMIN_ROLE_NAME="${SATELLITE_ADMIN_ROLE_NAME:-SatelliteAdmin}"
SATELLITE_ADMIN_USERNAME="${SATELLITE_ADMIN_USERNAME:-satelliteadmin}"
SATELLITE_ADMIN_EMAIL="${SATELLITE_ADMIN_EMAIL:-satelliteadmin@${SUB_DOMAIN}}"
SATELLITE_ADMIN_PASSWORD="${SATELLITE_ADMIN_PASSWORD:-}"
SATELLITE_ADMIN_FORCE_PASSWORD_CHANGE="${SATELLITE_ADMIN_FORCE_PASSWORD_CHANGE:-true}"
SATELLITE_ADMIN_FORCE_OTP_SETUP="${SATELLITE_ADMIN_FORCE_OTP_SETUP:-true}"
SATELLITE_ADMIN_FIRST_NAME="${SATELLITE_ADMIN_FIRST_NAME:-Satellite}"
SATELLITE_ADMIN_LAST_NAME="${SATELLITE_ADMIN_LAST_NAME:-Admin}"
SATELLITE_ADMIN_PARTY_ID="${SATELLITE_ADMIN_PARTY_ID:-${PARTY_ID:-}}"
SATELLITE_ADMIN_PARTY_NAME="${SATELLITE_ADMIN_PARTY_NAME:-${PARTY_NAME:-}}"
TARGET_REALM="${ORG_NAME}"
TARGET_CLIENT_ID="frontend"

GENERATED_PASSWORD=false
if [[ -z "${SATELLITE_ADMIN_PASSWORD}" ]]; then
  SATELLITE_ADMIN_PASSWORD="$(openssl rand -base64 24 | tr -d '\n' | tr -d '/+=' | cut -c1-20)Aa1!"
  GENERATED_PASSWORD=true
  warnln "SATELLITE_ADMIN_PASSWORD is empty; generated temporary password for this run: ${SATELLITE_ADMIN_PASSWORD}"
fi

KEYCLOAK_PATH_PREFIX="/${KEYCLOAK_PATH_PREFIX#/}"
KEYCLOAK_PATH_PREFIX="${KEYCLOAK_PATH_PREFIX%/}"
KEYCLOAK_PUBLIC_FRONTEND_URL="https://${KeycloakHostName}${KEYCLOAK_PATH_PREFIX}"
KEYCLOAK_API_BASE=""

case "${SATELLITE_ADMIN_FORCE_PASSWORD_CHANGE,,}" in
  true|false) ;;
  *)
    fatalln "SATELLITE_ADMIN_FORCE_PASSWORD_CHANGE must be true or false"
    ;;
esac

case "${SATELLITE_ADMIN_FORCE_OTP_SETUP,,}" in
  true|false) ;;
  *)
    fatalln "SATELLITE_ADMIN_FORCE_OTP_SETUP must be true or false"
    ;;
esac

if [[ -z "${SATELLITE_ADMIN_PARTY_ID}" ]]; then
  fatalln "SATELLITE_ADMIN_PARTY_ID (or PARTY_ID) must be set"
fi

if [[ -z "${SATELLITE_ADMIN_PARTY_NAME}" ]]; then
  fatalln "SATELLITE_ADMIN_PARTY_NAME (or PARTY_NAME) must be set"
fi

infoln "Provisioning SatelliteAdmin portal user '${SATELLITE_ADMIN_USERNAME}' in realm '${TARGET_REALM}'"

declare -a keycloak_candidates=()
keycloak_candidates+=("http://localhost:8080${KEYCLOAK_PATH_PREFIX}")
keycloak_candidates+=("http://localhost:8080")
keycloak_candidates+=("https://localhost:8443${KEYCLOAK_PATH_PREFIX}")
keycloak_candidates+=("https://localhost:8443")
keycloak_candidates+=("${KEYCLOAK_BASE_URL}${KEYCLOAK_PATH_PREFIX}")
if [[ "${KEYCLOAK_BASE_URL}${KEYCLOAK_PATH_PREFIX}" != "${KEYCLOAK_BASE_URL}" ]]; then
  keycloak_candidates+=("${KEYCLOAK_BASE_URL}")
fi

for candidate in "${keycloak_candidates[@]}"; do
  for _ in $(seq 1 20); do
    status_code="$(curl -ksS -o /dev/null -w "%{http_code}" "${candidate}/realms/master" || true)"
    if [[ "${status_code}" =~ ^[23][0-9][0-9]$ ]]; then
      KEYCLOAK_API_BASE="${candidate}"
      break
    fi
    sleep 2
  done
  if [[ -n "${KEYCLOAK_API_BASE}" ]]; then
    break
  fi
done

if [[ -z "${KEYCLOAK_API_BASE}" ]]; then
  fatalln "Keycloak admin API is not ready at any expected base URL (${keycloak_candidates[*]})"
fi

token_json="$(
  curl -ksS -X POST \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "client_id=admin-cli" \
    --data-urlencode "grant_type=password" \
    --data-urlencode "username=${KEYCLOAK_ADMIN_USER}" \
    --data-urlencode "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    "${KEYCLOAK_API_BASE}/realms/master/protocol/openid-connect/token"
)"

access_token="$(printf "%s" "${token_json}" | jq -r '.access_token // empty')"
if [[ -z "${access_token}" ]]; then
  fatalln "Failed to fetch Keycloak admin token. Check KEYCLOAK_ADMIN credentials and container health."
fi

auth_header=("Authorization: Bearer ${access_token}")

upsert_realm_frontend_url() {
  local realm_name="$1"
  local realm_payload
  local update_status

  realm_payload="$(
    curl -ksS \
      -H "${auth_header[0]}" \
      "${KEYCLOAK_API_BASE}/admin/realms/${realm_name}" \
      | jq --arg frontend_url "${KEYCLOAK_PUBLIC_FRONTEND_URL}" \
        '.attributes = (.attributes // {}) | .attributes.frontendUrl = $frontend_url'
  )"

  update_status="$(
    curl -ksS \
      -o "/tmp/satellite-admin-realm-${realm_name}.out" \
      -w "%{http_code}" \
      -X PUT \
      -H "${auth_header[0]}" \
      -H "Content-Type: application/json" \
      -d "${realm_payload}" \
      "${KEYCLOAK_API_BASE}/admin/realms/${realm_name}"
  )"

  if [[ "${update_status}" != "204" ]]; then
    errorln "Realm '${realm_name}' frontend URL update response body:"
    cat "/tmp/satellite-admin-realm-${realm_name}.out" >&2 || true
    fatalln "Failed setting realm '${realm_name}' frontendUrl to '${KEYCLOAK_PUBLIC_FRONTEND_URL}' (HTTP ${update_status})."
  fi
}

upsert_realm_frontend_url "master"
upsert_realm_frontend_url "${TARGET_REALM}"

client_internal_id="$(
  curl -ksS \
    -H "${auth_header[0]}" \
    "${KEYCLOAK_API_BASE}/admin/realms/${TARGET_REALM}/clients?clientId=${TARGET_CLIENT_ID}" \
    | jq -r '.[0].id // empty'
)"

if [[ -z "${client_internal_id}" ]]; then
  fatalln "Unable to find Keycloak client '${TARGET_CLIENT_ID}' in realm '${TARGET_REALM}'."
fi

ui_origin="https://${UIHostName}"
client_config_json="$(
  curl -ksS \
    -H "${auth_header[0]}" \
    "${KEYCLOAK_API_BASE}/admin/realms/${TARGET_REALM}/clients/${client_internal_id}"
)"

client_update_payload="$(
  printf "%s" "${client_config_json}" | jq \
    --arg ui_origin "${ui_origin}" \
    '
      .rootUrl = $ui_origin
      | .baseUrl = "/"
      | .redirectUris = [$ui_origin, ($ui_origin + "/"), ($ui_origin + "/*")]
      | .webOrigins = [$ui_origin]
    '
)"

client_update_status="$(
  curl -ksS \
    -o /tmp/satellite-admin-client-update.out \
    -w "%{http_code}" \
    -X PUT \
    -H "${auth_header[0]}" \
    -H "Content-Type: application/json" \
    -d "${client_update_payload}" \
    "${KEYCLOAK_API_BASE}/admin/realms/${TARGET_REALM}/clients/${client_internal_id}"
)"

if [[ "${client_update_status}" != "204" ]]; then
  errorln "Keycloak frontend client update response body:"
  cat /tmp/satellite-admin-client-update.out >&2 || true
  fatalln "Failed to align Keycloak frontend client CORS/redirects with UI origin '${ui_origin}' (HTTP ${client_update_status})."
fi
infoln "Frontend client CORS/redirects aligned to UI origin '${ui_origin}'"

user_id="$(
  curl -ksS \
    -H "${auth_header[0]}" \
    --get \
    --data-urlencode "username=${SATELLITE_ADMIN_USERNAME}" \
    --data-urlencode "exact=true" \
    "${KEYCLOAK_API_BASE}/admin/realms/${TARGET_REALM}/users" \
    | jq -r '.[0].id // empty'
)"

if [[ -z "${user_id}" ]]; then
  user_payload="$(
    jq -n \
      --arg username "${SATELLITE_ADMIN_USERNAME}" \
      --arg email "${SATELLITE_ADMIN_EMAIL}" \
      --arg first_name "${SATELLITE_ADMIN_FIRST_NAME}" \
      --arg last_name "${SATELLITE_ADMIN_LAST_NAME}" \
      --arg party_id "${SATELLITE_ADMIN_PARTY_ID}" \
      --arg party_name "${SATELLITE_ADMIN_PARTY_NAME}" \
      '{
        username: $username,
        enabled: true,
        emailVerified: true,
        email: $email,
        firstName: $first_name,
        lastName: $last_name,
        attributes: {
          partyId: [$party_id],
          partyName: [$party_name]
        }
      }'
  )"

  create_status="$(
    curl -ksS \
      -o /tmp/satellite-admin-create.out \
      -w "%{http_code}" \
      -X POST \
      -H "${auth_header[0]}" \
      -H "Content-Type: application/json" \
      -d "${user_payload}" \
      "${KEYCLOAK_API_BASE}/admin/realms/${TARGET_REALM}/users"
  )"

  if [[ "${create_status}" != "201" && "${create_status}" != "204" && "${create_status}" != "409" ]]; then
    errorln "Keycloak user creation response body:"
    cat /tmp/satellite-admin-create.out >&2 || true
    fatalln "Failed to create user '${SATELLITE_ADMIN_USERNAME}' (HTTP ${create_status})."
  fi
fi

user_id="$(
  curl -ksS \
    -H "${auth_header[0]}" \
    --get \
    --data-urlencode "username=${SATELLITE_ADMIN_USERNAME}" \
    --data-urlencode "exact=true" \
    "${KEYCLOAK_API_BASE}/admin/realms/${TARGET_REALM}/users" \
    | jq -r '.[0].id // empty'
)"

if [[ -z "${user_id}" ]]; then
  fatalln "Unable to resolve Keycloak user id for '${SATELLITE_ADMIN_USERNAME}' after create."
fi

password_payload="$(
  jq -n \
    --arg value "${SATELLITE_ADMIN_PASSWORD}" \
    --argjson temporary "$( [[ "${SATELLITE_ADMIN_FORCE_PASSWORD_CHANGE,,}" == "true" ]] && echo true || echo false )" \
    '{type:"password", value:$value, temporary:$temporary}'
)"

password_status="$(
  curl -ksS \
    -o /tmp/satellite-admin-password.out \
    -w "%{http_code}" \
    -X PUT \
    -H "${auth_header[0]}" \
    -H "Content-Type: application/json" \
    -d "${password_payload}" \
    "${KEYCLOAK_API_BASE}/admin/realms/${TARGET_REALM}/users/${user_id}/reset-password"
)"

if [[ "${password_status}" != "204" ]]; then
  errorln "Keycloak reset-password response body:"
  cat /tmp/satellite-admin-password.out >&2 || true
  fatalln "Failed to set password for '${SATELLITE_ADMIN_USERNAME}' (HTTP ${password_status})."
fi

user_update_payload="$(
  curl -ksS \
    -H "${auth_header[0]}" \
    "${KEYCLOAK_API_BASE}/admin/realms/${TARGET_REALM}/users/${user_id}" \
    | jq \
      --arg party_id "${SATELLITE_ADMIN_PARTY_ID}" \
      --arg party_name "${SATELLITE_ADMIN_PARTY_NAME}" \
      --argjson force_change "$( [[ "${SATELLITE_ADMIN_FORCE_PASSWORD_CHANGE,,}" == "true" ]] && echo true || echo false )" \
      --argjson force_otp "$( [[ "${SATELLITE_ADMIN_FORCE_OTP_SETUP,,}" == "true" ]] && echo true || echo false )" \
      '
        .requiredActions = (.requiredActions // [])
        | .attributes = (.attributes // {})
        | .attributes.partyId = [$party_id]
        | .attributes.partyName = [$party_name]
        | if $force_change
          then .requiredActions = ((.requiredActions + ["UPDATE_PASSWORD"]) | unique)
          else .requiredActions = (.requiredActions - ["UPDATE_PASSWORD"])
          end
        | if $force_otp
          then .requiredActions = ((.requiredActions + ["CONFIGURE_TOTP"]) | unique)
          else .requiredActions = (.requiredActions - ["CONFIGURE_TOTP"])
          end
      '
)"

user_update_status="$(
  curl -ksS \
    -o /tmp/satellite-admin-user-update.out \
    -w "%{http_code}" \
    -X PUT \
    -H "${auth_header[0]}" \
    -H "Content-Type: application/json" \
    -d "${user_update_payload}" \
    "${KEYCLOAK_API_BASE}/admin/realms/${TARGET_REALM}/users/${user_id}"
)"

if [[ "${user_update_status}" != "204" ]]; then
  errorln "Keycloak user update response body:"
  cat /tmp/satellite-admin-user-update.out >&2 || true
  fatalln "Failed updating required actions for '${SATELLITE_ADMIN_USERNAME}' (HTTP ${user_update_status})."
fi

role_object="$(
  curl -ksS \
    -H "${auth_header[0]}" \
    "${KEYCLOAK_API_BASE}/admin/realms/${TARGET_REALM}/clients/${client_internal_id}/roles" \
    | jq -c \
      --arg role_name_lower "$(printf "%s" "${SATELLITE_ADMIN_ROLE_NAME}" | tr '[:upper:]' '[:lower:]')" \
      '[.[] | select((.name | ascii_downcase) == $role_name_lower)] | .[0] // empty'
)"

if [[ -z "${role_object}" ]]; then
  fatalln "Could not find client role '${SATELLITE_ADMIN_ROLE_NAME}' on client '${TARGET_CLIENT_ID}'."
fi

existing_role_count="$(
  curl -ksS \
    -H "${auth_header[0]}" \
    "${KEYCLOAK_API_BASE}/admin/realms/${TARGET_REALM}/users/${user_id}/role-mappings/clients/${client_internal_id}" \
    | jq \
      --arg role_name_lower "$(printf "%s" "${SATELLITE_ADMIN_ROLE_NAME}" | tr '[:upper:]' '[:lower:]')" \
      '[.[] | select((.name | ascii_downcase) == $role_name_lower)] | length'
)"

if [[ "${existing_role_count}" -eq 0 ]]; then
  role_assign_status="$(
    curl -ksS \
      -o /tmp/satellite-admin-role.out \
      -w "%{http_code}" \
      -X POST \
      -H "${auth_header[0]}" \
      -H "Content-Type: application/json" \
      -d "[${role_object}]" \
      "${KEYCLOAK_API_BASE}/admin/realms/${TARGET_REALM}/users/${user_id}/role-mappings/clients/${client_internal_id}"
  )"

  if [[ "${role_assign_status}" != "204" ]]; then
    errorln "Keycloak role assignment response body:"
    cat /tmp/satellite-admin-role.out >&2 || true
    fatalln "Failed assigning role '${SATELLITE_ADMIN_ROLE_NAME}' to '${SATELLITE_ADMIN_USERNAME}' (HTTP ${role_assign_status})."
  fi
fi

infoln "SatelliteAdmin user ready: username='${SATELLITE_ADMIN_USERNAME}', realm='${TARGET_REALM}', role='${SATELLITE_ADMIN_ROLE_NAME}'"
repo_root_hint="${REPO_ROOT:-$(cd .. && pwd)}"
if [[ "${GENERATED_PASSWORD}" == "true" ]]; then
  warnln "Using generated temporary password (shown above). Persist it in ${repo_root_hint}/.env.server if needed, then rotate after first login."
else
  warnln "Initial portal password is stored in SATELLITE_ADMIN_PASSWORD in ${repo_root_hint}/.env.server. Rotate it after first login."
fi
