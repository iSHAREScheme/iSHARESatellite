#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck disable=SC1091
source "${REPO_ROOT}/scripts/lib/install-common.sh"

STATE_DIR="${REPO_ROOT}/.local-state/server-install"
REPORT_DIR="${STATE_DIR}/reports"
STATE_FILE="${STATE_DIR}/state.env"
LAST_ERROR_FILE="${STATE_DIR}/last-error.log"
EXTERNAL_STATE_FILE="${STATE_DIR}/external-gates.env"
INSTALL_BIN_DIR="${STATE_DIR}/bin"
EXAMPLE_ENV_FILE="${REPO_ROOT}/.env.server.example"
ENV_FILE="${REPO_ROOT}/.env.server"
NON_INTERACTIVE=false
RESUME=false
TARGET_STAGE=""
FORCE_STAGE=""
RESET_STATE=false
TARGET_STAGE_RAN=false
SHOW_EXTERNAL_GATES=false
REPORT_FILE=""
RUN_STARTED_AT="$(date +"%Y-%m-%dT%H:%M:%S%z")"
CURRENT_STAGE="bootstrap"
FINAL_STATUS_OVERRIDE=""
FINAL_STATUS_MESSAGE=""
PAUSE_AFTER_STAGE=false
PAUSE_GATE_ID=""
PAUSE_REASON=""
STAGE_PAUSE_REQUESTED=false
INSTALLER_PAUSED=false
LAST_SCRIPT_NAME=""
LAST_SCRIPT_OUTPUT=""

EXTERNAL_GATE_KEYS=(
  EXT_ORG_JSON
  EXT_FOUNDATION_PACKAGE
  EXT_CHANNEL_ADMISSION
  EXT_TLS_MATERIAL
  EXT_JWT_MATERIAL
  EXT_APP_DNS
  EXT_SMTP
)

EXT_ORG_JSON_STATUS="pending"
EXT_ORG_JSON_NOTE=""
EXT_ORG_JSON_UPDATED_AT=""
EXT_FOUNDATION_PACKAGE_STATUS="pending"
EXT_FOUNDATION_PACKAGE_NOTE=""
EXT_FOUNDATION_PACKAGE_UPDATED_AT=""
EXT_CHANNEL_ADMISSION_STATUS="pending"
EXT_CHANNEL_ADMISSION_NOTE=""
EXT_CHANNEL_ADMISSION_UPDATED_AT=""
EXT_TLS_MATERIAL_STATUS="pending"
EXT_TLS_MATERIAL_NOTE=""
EXT_TLS_MATERIAL_UPDATED_AT=""
EXT_JWT_MATERIAL_STATUS="pending"
EXT_JWT_MATERIAL_NOTE=""
EXT_JWT_MATERIAL_UPDATED_AT=""
EXT_APP_DNS_STATUS="pending"
EXT_APP_DNS_NOTE=""
EXT_APP_DNS_UPDATED_AT=""
EXT_SMTP_STATUS="pending"
EXT_SMTP_NOTE=""
EXT_SMTP_UPDATED_AT=""

STAGE_KEYS=(
  "preflight"
  "env"
  "fabric-base"
  "org-artifact"
  "join-network"
  "app-deploy"
)

REQUIRED_ENV_VARS=(
  ORG_NAME
  SUB_DOMAIN
  ENVIRONMENT
  ORDERER_ADDRESS
  ORDERER_TLS_CA_CERT
  CHANNEL_NAME
  ANCHOR_PEER_HOSTNAME
  ANCHOR_PEER_PORT_NUMBER
  CHAINCODE_NAME
  CHAINCODE_VERSION
  CHAINCODE_SEQUENCE
  CHAINCODE_POLICY
  PEER_ADMIN_MSP_DIR
  PARTY_ID
  PARTY_NAME
  UIHostName
  MiddlewareHostName
  KeycloakHostName
  SMTP_PORT
  SMTP_HOST
  SMTP_USER
  SMTP_PASSWORD
  DISPLAY_NAME
)

ALL_ENV_VARS=(
  ORG_NAME
  SUB_DOMAIN
  ENVIRONMENT
  REGISTERAR_NAME
  ENROLLMENT_SECRET
  FABRIC_CA_ADDRESS
  PEER_COUNT
  ORDERER_COUNT
  ORDERER_ADDRESS
  ORDERER_TLS_CA_CERT
  CHANNEL_NAME
  ANCHOR_PEER_HOSTNAME
  ANCHOR_PEER_PORT_NUMBER
  CHAINCODE_LABEL
  CHAINCODE_NAME
  CHAINCODE_VERSION
  CHAINCODE_SEQUENCE
  CHAINCODE_POLICY
  CC_PACKAGE_ID
  PEER_ADMIN_MSP_DIR
  PARTY_ID
  PARTY_NAME
  UIHostName
  MiddlewareHostName
  KeycloakHostName
  SMTP_PORT
  SMTP_HOST
  SMTP_USER
  SMTP_PASSWORD
  DISPLAY_NAME
  SATELLITE_ADMIN_USERNAME
  SATELLITE_ADMIN_EMAIL
  SATELLITE_ADMIN_PASSWORD
)

init_report() {
  mkdir -p "${REPORT_DIR}"
  REPORT_FILE="${REPORT_DIR}/report-$(date +"%Y%m%d-%H%M%S").txt"
  {
    printf "Server Installer Validation Report\n"
    printf "Generated: %s\n" "$(date +"%Y-%m-%d %H:%M:%S")"
    printf "Repo: %s\n" "${REPO_ROOT}"
    printf "Env file: %s\n" "${ENV_FILE}"
    printf "\n"
  } >"${REPORT_FILE}"
}

report_line() {
  local stage="$1"
  local status="$2"
  local check_name="$3"
  local detail="$4"
  printf "[%s] [%s] %-5s | %s | %s\n" \
    "$(date +"%Y-%m-%d %H:%M:%S")" "${stage}" "${status}" "${check_name}" "${detail}" >>"${REPORT_FILE}"
}

report_stage_header() {
  local stage="$1"
  local title="$2"
  {
    printf "\n"
    printf "=== %s (%s) ===\n" "${title}" "${stage}"
  } >>"${REPORT_FILE}"
}

report_pass() {
  report_line "$1" "PASS" "$2" "$3"
}

report_warn() {
  report_line "$1" "WARN" "$2" "$3"
}

report_fail() {
  report_line "$1" "FAIL" "$2" "$3"
}

report_skip() {
  report_line "$1" "SKIP" "$2" "$3"
}

report_assert_file() {
  local stage="$1"
  local file_path="$2"
  local label="$3"
  if [[ -f "${file_path}" ]]; then
    report_pass "${stage}" "${label}" "${file_path}"
  else
    report_fail "${stage}" "${label}" "Missing file: ${file_path}"
    die "${label}: missing file ${file_path}"
  fi
}

report_assert_nonempty_file() {
  local stage="$1"
  local file_path="$2"
  local label="$3"
  if [[ -s "${file_path}" ]]; then
    report_pass "${stage}" "${label}" "${file_path}"
  else
    report_fail "${stage}" "${label}" "Missing or empty file: ${file_path}"
    die "${label}: missing or empty file ${file_path}"
  fi
}

report_assert_compose_running() {
  local stage="$1"
  local compose_file="$2"
  local label="$3"
  local running_services
  local running_count

  if ! running_services="$(docker-compose -f "${compose_file}" ps --services --filter status=running 2>/dev/null)"; then
    report_fail "${stage}" "${label}" "docker-compose status failed for ${compose_file}"
    die "${label}: unable to read docker-compose status for ${compose_file}"
  fi

  running_count="$(printf "%s\n" "${running_services}" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [[ "${running_count}" -gt 0 ]]; then
    report_pass "${stage}" "${label}" "${running_count} running service(s)"
  else
    report_fail "${stage}" "${label}" "No running services for ${compose_file}"
    die "${label}: no running services for ${compose_file}"
  fi
}

run_script_with_report() {
  local stage="$1"
  local script_name="$2"
  local output

  LAST_SCRIPT_NAME="${script_name}"
  LAST_SCRIPT_OUTPUT=""
  if output="$(run_repo_script "${REPO_ROOT}" "${ENV_FILE}" "${script_name}" 2>&1)"; then
    LAST_SCRIPT_OUTPUT="${output}"
    if [[ -n "${output}" ]]; then
      printf "%s\n" "${output}"
    fi
    report_pass "${stage}" "scripts/${script_name}" "completed"
  else
    LAST_SCRIPT_OUTPUT="${output}"
    if [[ -n "${output}" ]]; then
      printf "%s\n" "${output}" >&2
    fi
    report_fail "${stage}" "scripts/${script_name}" "failed"
    return 1
  fi
}

write_state_file() {
  local status="$1"
  local message="${2:-}"
  mkdir -p "${STATE_DIR}"
  {
    printf "export INSTALL_STATUS=%s\n" "$(shell_quote "${status}")"
    printf "export INSTALL_MESSAGE=%s\n" "$(shell_quote "${message}")"
    printf "export INSTALL_STARTED_AT=%s\n" "$(shell_quote "${RUN_STARTED_AT}")"
    printf "export INSTALL_UPDATED_AT=%s\n" "$(shell_quote "$(date +"%Y-%m-%dT%H:%M:%S%z")")"
    printf "export INSTALL_LAST_STAGE=%s\n" "$(shell_quote "${CURRENT_STAGE}")"
    printf "export INSTALL_ENV_FILE=%s\n" "$(shell_quote "${ENV_FILE}")"
    printf "export INSTALL_NON_INTERACTIVE=%s\n" "$(shell_quote "${NON_INTERACTIVE}")"
    printf "export INSTALL_RESUME=%s\n" "$(shell_quote "${RESUME}")"
    printf "export INSTALL_TARGET_STAGE=%s\n" "$(shell_quote "${TARGET_STAGE}")"
    printf "export INSTALL_FORCE_STAGE=%s\n" "$(shell_quote "${FORCE_STAGE}")"
    printf "export INSTALL_REPORT_FILE=%s\n" "$(shell_quote "${REPORT_FILE}")"
    printf "export INSTALL_EXTERNAL_STATE_FILE=%s\n" "$(shell_quote "${EXTERNAL_STATE_FILE}")"
  } >"${STATE_FILE}"
}

resume_command() {
  local cmd="bash scripts/install-server.sh --resume"
  if [[ "${ENV_FILE}" != "${REPO_ROOT}/.env.server" ]]; then
    cmd="${cmd} --env-file ${ENV_FILE}"
  fi
  if [[ "${NON_INTERACTIVE}" == "true" ]]; then
    cmd="${cmd} --non-interactive"
  fi
  printf "%s" "${cmd}"
}

resume_stage_command() {
  local stage="$1"
  printf "%s --force-stage %s" "$(resume_command)" "${stage}"
}

persist_external_state() {
  local gate
  local status_var
  local note_var
  local updated_var

  mkdir -p "${STATE_DIR}"
  {
    printf "# External gate state for install-server.sh\n"
    printf "# Updated on %s\n\n" "$(date +"%Y-%m-%d %H:%M:%S")"
    for gate in "${EXTERNAL_GATE_KEYS[@]}"; do
      status_var="${gate}_STATUS"
      note_var="${gate}_NOTE"
      updated_var="${gate}_UPDATED_AT"
      printf "export %s=%s\n" "${status_var}" "$(shell_quote "${!status_var:-pending}")"
      printf "export %s=%s\n" "${note_var}" "$(shell_quote "${!note_var:-}")"
      printf "export %s=%s\n" "${updated_var}" "$(shell_quote "${!updated_var:-}")"
    done
  } >"${EXTERNAL_STATE_FILE}"
}

load_external_state() {
  if [[ -f "${EXTERNAL_STATE_FILE}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${EXTERNAL_STATE_FILE}"
    set +a
  fi
}

init_external_state() {
  if [[ ! -f "${EXTERNAL_STATE_FILE}" ]]; then
    persist_external_state
    return
  fi
  load_external_state
}

external_gate_title() {
  local gate="$1"
  case "${gate}" in
    EXT_ORG_JSON) printf "Org JSON Handoff" ;;
    EXT_FOUNDATION_PACKAGE) printf "Foundation Package" ;;
    EXT_CHANNEL_ADMISSION) printf "Channel Admission" ;;
    EXT_TLS_MATERIAL) printf "TLS Material" ;;
    EXT_JWT_MATERIAL) printf "JWT Material" ;;
    EXT_APP_DNS) printf "App DNS" ;;
    EXT_SMTP) printf "SMTP" ;;
    *) printf "%s" "${gate}" ;;
  esac
}

print_external_gates() {
  local gate
  local status_var
  local note_var
  local updated_var
  local status
  local note
  local updated_at

  printf "External Gate Status\n"
  printf "State file: %s\n" "${EXTERNAL_STATE_FILE}"
  printf "\n"
  printf "%-24s %-18s %-25s %s\n" "Gate" "Status" "Updated At" "Note"
  printf "%-24s %-18s %-25s %s\n" "----" "------" "----------" "----"

  for gate in "${EXTERNAL_GATE_KEYS[@]}"; do
    status_var="${gate}_STATUS"
    note_var="${gate}_NOTE"
    updated_var="${gate}_UPDATED_AT"
    status="${!status_var:-pending}"
    note="${!note_var:-}"
    updated_at="${!updated_var:-}"
    if [[ -z "${updated_at}" ]]; then
      updated_at="-"
    fi
    if [[ -z "${note}" ]]; then
      note="-"
    fi
    printf "%-24s %-18s %-25s %s\n" "$(external_gate_title "${gate}")" "${status}" "${updated_at}" "${note}"
  done
}

set_external_gate() {
  local gate="$1"
  local status="$2"
  local note="${3:-}"
  local status_var="${gate}_STATUS"
  local note_var="${gate}_NOTE"
  local updated_var="${gate}_UPDATED_AT"

  printf -v "${status_var}" "%s" "${status}"
  printf -v "${note_var}" "%s" "${note}"
  printf -v "${updated_var}" "%s" "$(date +"%Y-%m-%dT%H:%M:%S%z")"
  persist_external_state
}

get_external_gate_status() {
  local gate="$1"
  local status_var="${gate}_STATUS"
  printf "%s" "${!status_var:-pending}"
}

request_external_pause_after_stage() {
  local gate_id="$1"
  local reason="$2"
  PAUSE_AFTER_STAGE=true
  PAUSE_GATE_ID="${gate_id}"
  PAUSE_REASON="${reason}"
}

wait_for_external_and_return() {
  local gate_id="$1"
  local reason="$2"
  FINAL_STATUS_OVERRIDE="WAITING_EXTERNAL"
  FINAL_STATUS_MESSAGE="${reason}"
  STAGE_PAUSE_REQUESTED=true
  INSTALLER_PAUSED=true
  write_state_file "WAITING_EXTERNAL" "${reason}"
  log_warn "External gate ${gate_id} is waiting: ${reason}"
  log_info "Resume command: $(resume_command)"
  return 0
}

require_external_file_or_die() {
  local stage="$1"
  local gate="$2"
  local file_path="$3"
  local label="$4"
  local why="$5"
  local next_action="$6"

  if [[ -f "${file_path}" ]]; then
    report_pass "${stage}" "${label}" "${file_path}"
    return
  fi

  set_external_gate "${gate}" "blocked" "Missing ${file_path}"
  report_fail "${stage}" "${label}" "Missing file: ${file_path}"
  die "External requirement missing (${label}): ${file_path}. Why: ${why}. Next: ${next_action}. Rerun: $(resume_stage_command "${stage}")"
}

report_dns_resolution_warning() {
  local stage="$1"
  local host="$2"
  local label="$3"
  if getent hosts "${host}" >/dev/null 2>&1; then
    report_pass "${stage}" "${label}" "Resolves: ${host}"
  else
    report_warn "${stage}" "${label}" "Cannot resolve ${host} yet"
  fi
}

report_smtp_connectivity_warning() {
  local stage="$1"
  local host="$2"
  local port="$3"
  if command -v nc >/dev/null 2>&1; then
    if nc -z -w 3 "${host}" "${port}" >/dev/null 2>&1; then
      report_pass "${stage}" "SMTP connectivity" "${host}:${port} reachable"
    else
      report_warn "${stage}" "SMTP connectivity" "Cannot connect to ${host}:${port} (continuing as warning)"
    fi
  else
    report_warn "${stage}" "SMTP connectivity" "nc not available; skipped connectivity probe for ${host}:${port}"
  fi
}

handle_join_network_script_failure() {
  local stage="$1"
  local script_name="$2"
  local output="${LAST_SCRIPT_OUTPUT}"

  if printf "%s" "${output}" | grep -Eq "FORBIDDEN|can't read the block"; then
    set_external_gate "EXT_CHANNEL_ADMISSION" "waiting_external" "Orderer denied channel block access (likely org not admitted yet)"
    report_fail "${stage}" "External gate EXT-04 channel admission" "Orderer denied channel access while running ${script_name}"
    die "Join failed with FORBIDDEN while running ${script_name}. Your org is likely not yet admitted to channel '${CHANNEL_NAME}'. Ask Foundation to confirm channel admission, then rerun: $(resume_stage_command "${stage}")"
  fi

  die "Stage ${stage} failed while running scripts/${script_name}. Review the output above and rerun: $(resume_stage_command "${stage}")"
}

write_last_error_file() {
  local exit_code="$1"
  local message="${2:-installer failed}"
  mkdir -p "${STATE_DIR}"
  {
    printf "timestamp=%s\n" "$(date +"%Y-%m-%dT%H:%M:%S%z")"
    printf "exit_code=%s\n" "${exit_code}"
    printf "stage=%s\n" "${CURRENT_STAGE}"
    printf "message=%s\n" "${message}"
    printf "env_file=%s\n" "${ENV_FILE}"
    printf "report_file=%s\n" "${REPORT_FILE}"
  } >"${LAST_ERROR_FILE}"
}

is_positive_integer() {
  local value="$1"
  [[ "${value}" =~ ^[0-9]+$ ]] && [[ "${value}" -gt 0 ]]
}

is_valid_port() {
  local value="$1"
  is_positive_integer "${value}" && [[ "${value}" -le 65535 ]]
}

is_valid_hostname() {
  local value="$1"
  if [[ "${value}" == "localhost" ]]; then
    return 0
  fi
  # DNS label style hostnames with dots.
  [[ "${value}" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$ ]]
}

is_valid_host_port() {
  local value="$1"
  local host="${value%:*}"
  local port="${value##*:}"
  if [[ "${host}" == "${value}" || -z "${host}" || -z "${port}" ]]; then
    return 1
  fi
  is_valid_hostname "${host}" && is_valid_port "${port}"
}

has_no_newline() {
  local value="$1"
  [[ "${value}" != *$'\n'* ]]
}

report_key_permission_warning() {
  local stage="$1"
  local key_file="$2"
  local label="$3"
  local mode
  local perm
  local group
  local other

  if mode="$(stat -c "%a" "${key_file}" 2>/dev/null)"; then
    :
  elif mode="$(stat -f "%Lp" "${key_file}" 2>/dev/null)"; then
    :
  else
    report_warn "${stage}" "${label} permissions" "Unable to determine mode for ${key_file}"
    return
  fi

  perm="${mode: -3}"
  if [[ ! "${perm}" =~ ^[0-7]{3}$ ]]; then
    report_warn "${stage}" "${label} permissions" "Unexpected mode format '${mode}' for ${key_file}"
    return
  fi

  group="${perm:1:1}"
  other="${perm:2:1}"
  if [[ "${group}" != "0" || "${other}" != "0" ]]; then
    report_warn "${stage}" "${label} permissions" "Mode ${perm} is broad; prefer 600 or stricter"
  else
    report_pass "${stage}" "${label} permissions" "Mode ${perm}"
  fi
}

usage() {
  cat <<EOF
Usage: bash scripts/install-server.sh [options]

Mode behavior:
  Interactive (default): prompts for required values, explains each one, and pre-fills common defaults.
                        Creates/updates ENV_FILE.
  Non-interactive: requires an existing complete ENV_FILE.

Options:
  --env-file <path>       Path to env file (default: ${ENV_FILE})
  --non-interactive       Do not prompt; require a complete env file
  --resume                Skip completed stages (uses ${STATE_DIR})
  --stage <name>          Run only one stage
  --force-stage <name>    Re-run a stage even if checkpoint exists
  --reset-state           Clear checkpoints before execution
  --show-external-gates   Print external gate statuses and exit
  --list-stages           Print stage names and exit
  -h, --help              Show this help

Stages:
  preflight | env | fabric-base | org-artifact | join-network | app-deploy
EOF
}

is_valid_stage() {
  local needle="$1"
  local stage
  for stage in "${STAGE_KEYS[@]}"; do
    if [[ "$stage" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --env-file)
        [[ $# -ge 2 ]] || die "Missing value for --env-file"
        ENV_FILE="$2"
        shift 2
        ;;
      --non-interactive)
        NON_INTERACTIVE=true
        shift
        ;;
      --resume)
        RESUME=true
        shift
        ;;
      --stage)
        [[ $# -ge 2 ]] || die "Missing value for --stage"
        TARGET_STAGE="$2"
        shift 2
        ;;
      --force-stage)
        [[ $# -ge 2 ]] || die "Missing value for --force-stage"
        FORCE_STAGE="$2"
        shift 2
        ;;
      --reset-state)
        RESET_STATE=true
        shift
        ;;
      --show-external-gates)
        SHOW_EXTERNAL_GATES=true
        shift
        ;;
      --list-stages)
        printf "%s\n" "${STAGE_KEYS[@]}"
        exit 0
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done
}

load_env_file() {
  export REPO_ROOT
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
}

set_defaults() {
  : "${REGISTERAR_NAME:=admin}"
  : "${ENROLLMENT_SECRET:=adminpw}"
  : "${FABRIC_CA_ADDRESS:=localhost:7054}"
  : "${PEER_COUNT:=2}"
  : "${ORDERER_COUNT:=0}"
  : "${CHAINCODE_LABEL:=isharecc_1.0}"
  : "${SATELLITE_ADMIN_USERNAME:=satelliteadmin}"
  : "${SATELLITE_ADMIN_PASSWORD:=}"
}

set_derived_defaults() {
  if [[ -n "${SUB_DOMAIN:-}" ]]; then
    : "${SATELLITE_ADMIN_EMAIL:=satelliteadmin@${SUB_DOMAIN}}"
  else
    : "${SATELLITE_ADMIN_EMAIL:=satelliteadmin@example.com}"
  fi
}

validate_org_name() {
  if [[ -z "${ORG_NAME}" ]]; then
    die "ORG_NAME is required"
  fi
  if [[ ${#ORG_NAME} -gt 17 ]]; then
    die "ORG_NAME must be 17 characters or fewer"
  fi
  if [[ ! "${ORG_NAME}" =~ ^[a-zA-Z0-9]+$ ]]; then
    die "ORG_NAME must be alphanumeric"
  fi
}

validate_required_env() {
  local key
  for key in "${REQUIRED_ENV_VARS[@]}"; do
    if [[ -z "${!key:-}" ]]; then
      die "Missing required env var: ${key}"
    fi
  done
  validate_org_name
}

extract_semver() {
  local raw="$1"
  printf "%s\n" "${raw}" | sed -nE 's/.*v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' | head -n 1
}

normalize_version() {
  local raw="$1"
  local major minor patch

  if [[ ! "${raw}" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
    printf ""
    return
  fi

  IFS='.' read -r major minor patch <<<"${raw}"
  printf "%s.%s.%s" "${major:-0}" "${minor:-0}" "${patch:-0}"
}

version_lt() {
  local left="$1"
  local right="$2"
  [[ "$(printf "%s\n%s\n" "${left}" "${right}" | sort -V | head -n 1)" == "${left}" && "${left}" != "${right}" ]]
}

prompt_required_with_example() {
  local label="$1"
  local current_value="$2"
  local example_value="$3"
  local value=""
  local prompt

  prompt="${label} (example: ${example_value})"
  value="${current_value}"
  while true; do
    value="$(prompt_value "${prompt}" "${value}")"
    if [[ -n "${value}" ]]; then
      printf "%s" "${value}"
      return
    fi
    log_warn "${label} is required"
  done
}

prompt_required_secret_with_example() {
  local label="$1"
  local current_value="$2"
  local example_value="$3"
  local value=""
  local prompt

  prompt="${label} (example: ${example_value})"
  value="${current_value}"
  while true; do
    value="$(prompt_secret "${prompt}" "${value}")"
    if [[ -n "${value}" ]]; then
      printf "%s" "${value}"
      return
    fi
    log_warn "${label} is required"
  done
}

prompt_required_with_context() {
  local label="$1"
  local current_value="$2"
  local example_value="$3"
  local explanation="$4"
  log_info "${label}: ${explanation}" >&2
  prompt_required_with_example "${label}" "${current_value}" "${example_value}"
}

prompt_required_secret_with_context() {
  local label="$1"
  local current_value="$2"
  local example_value="$3"
  local explanation="$4"
  log_info "${label}: ${explanation}" >&2
  prompt_required_secret_with_example "${label}" "${current_value}" "${example_value}"
}

validate_env_format_with_report() {
  local stage="$1"

  if [[ "${ENVIRONMENT}" =~ ^[A-Za-z0-9._-]+$ ]]; then
    report_pass "${stage}" "ENVIRONMENT format" "${ENVIRONMENT}"
  else
    report_fail "${stage}" "ENVIRONMENT format" "Invalid ENVIRONMENT '${ENVIRONMENT}'"
    die "ENVIRONMENT must use letters, digits, dot, underscore, or hyphen"
  fi

  if is_valid_host_port "${ORDERER_ADDRESS}"; then
    report_pass "${stage}" "ORDERER_ADDRESS format" "${ORDERER_ADDRESS}"
  else
    report_fail "${stage}" "ORDERER_ADDRESS format" "Expected host:port, got '${ORDERER_ADDRESS}'"
    die "ORDERER_ADDRESS must be in host:port format"
  fi

  if is_valid_hostname "${UIHostName}"; then
    report_pass "${stage}" "UIHostName format" "${UIHostName}"
  else
    report_fail "${stage}" "UIHostName format" "Invalid hostname '${UIHostName}'"
    die "UIHostName is not a valid hostname"
  fi

  if is_valid_hostname "${MiddlewareHostName}"; then
    report_pass "${stage}" "MiddlewareHostName format" "${MiddlewareHostName}"
  else
    report_fail "${stage}" "MiddlewareHostName format" "Invalid hostname '${MiddlewareHostName}'"
    die "MiddlewareHostName is not a valid hostname"
  fi

  if is_valid_hostname "${KeycloakHostName}"; then
    report_pass "${stage}" "KeycloakHostName format" "${KeycloakHostName}"
  else
    report_fail "${stage}" "KeycloakHostName format" "Invalid hostname '${KeycloakHostName}'"
    die "KeycloakHostName is not a valid hostname"
  fi

  if is_valid_hostname "${ANCHOR_PEER_HOSTNAME}"; then
    report_pass "${stage}" "ANCHOR_PEER_HOSTNAME format" "${ANCHOR_PEER_HOSTNAME}"
  else
    report_fail "${stage}" "ANCHOR_PEER_HOSTNAME format" "Invalid hostname '${ANCHOR_PEER_HOSTNAME}'"
    die "ANCHOR_PEER_HOSTNAME is not a valid hostname"
  fi

  if is_valid_port "${ANCHOR_PEER_PORT_NUMBER}"; then
    report_pass "${stage}" "ANCHOR_PEER_PORT_NUMBER format" "${ANCHOR_PEER_PORT_NUMBER}"
  else
    report_fail "${stage}" "ANCHOR_PEER_PORT_NUMBER format" "Invalid port '${ANCHOR_PEER_PORT_NUMBER}'"
    die "ANCHOR_PEER_PORT_NUMBER must be an integer between 1 and 65535"
  fi

  if is_valid_port "${SMTP_PORT}"; then
    report_pass "${stage}" "SMTP_PORT format" "${SMTP_PORT}"
  else
    report_fail "${stage}" "SMTP_PORT format" "Invalid port '${SMTP_PORT}'"
    die "SMTP_PORT must be an integer between 1 and 65535"
  fi

  if is_positive_integer "${CHAINCODE_SEQUENCE}"; then
    report_pass "${stage}" "CHAINCODE_SEQUENCE format" "${CHAINCODE_SEQUENCE}"
  else
    report_fail "${stage}" "CHAINCODE_SEQUENCE format" "Invalid value '${CHAINCODE_SEQUENCE}'"
    die "CHAINCODE_SEQUENCE must be a positive integer"
  fi

  if has_no_newline "${ORDERER_TLS_CA_CERT}"; then
    report_pass "${stage}" "ORDERER_TLS_CA_CERT syntax" "${ORDERER_TLS_CA_CERT}"
  else
    report_fail "${stage}" "ORDERER_TLS_CA_CERT syntax" "Contains newline characters"
    die "ORDERER_TLS_CA_CERT must be a single-line path"
  fi

  if has_no_newline "${PEER_ADMIN_MSP_DIR}"; then
    report_pass "${stage}" "PEER_ADMIN_MSP_DIR syntax" "${PEER_ADMIN_MSP_DIR}"
  else
    report_fail "${stage}" "PEER_ADMIN_MSP_DIR syntax" "Contains newline characters"
    die "PEER_ADMIN_MSP_DIR must be a single-line path"
  fi

  if [[ ! "${ORDERER_TLS_CA_CERT}" = /* ]]; then
    report_warn "${stage}" "ORDERER_TLS_CA_CERT style" "Relative path detected; interpreted relative to repo root"
  fi
  if [[ ! "${PEER_ADMIN_MSP_DIR}" = /* ]]; then
    report_warn "${stage}" "PEER_ADMIN_MSP_DIR style" "Relative path detected; interpreted by scripts at runtime"
  fi
}

write_env_file() {
  local key
  {
    printf "# Server deploy environment for install-server.sh\n"
    printf "# Generated on %s\n\n" "$(date +"%Y-%m-%d %H:%M:%S")"
    for key in "${ALL_ENV_VARS[@]}"; do
      printf "export %s=%s\n" "$key" "$(shell_quote "${!key:-}")"
    done
  } >"${ENV_FILE}"
}

interactive_capture_env() {
  local org_example="mysatellite"
  local sub_domain_example="test.example.com"
  local environment_example="test"
  local orderer_address_example="orderer1.example.aks.io:443"
  local channel_example="appchannel"
  local chaincode_name_example="isharecode"
  local chaincode_version_example="v1"
  local chaincode_sequence_example="1"
  local chaincode_policy_example
  local peer_admin_msp_example
  local orderer_tls_ca_example
  local anchor_peer_example
  local party_id_example="EU.EORI.NL000000000"
  local party_name_example="Example Organization"
  local ui_hostname_example="satellite.example.com"
  local mw_hostname_example="satellite-mw.example.com"
  local kc_hostname_example="satellite-kc.example.com"
  local smtp_port_example="587"
  local smtp_host_example="smtp.example.com"
  local smtp_user_example="noreply@example.com"
  local smtp_password_example="change-me"
  local display_name_example="iSHARE Satellite"
  local satellite_admin_username_example="satelliteadmin"
  local satellite_admin_email_example
  local satellite_admin_password_example="ChangeMe123!"
  local channel_default
  local anchor_peer_default
  local anchor_peer_port_default
  local chaincode_name_default
  local chaincode_version_default
  local chaincode_sequence_default
  local chaincode_policy_default
  local peer_admin_msp_default
  local orderer_tls_ca_default
  local satellite_admin_username_default
  local satellite_admin_email_default

  log_info "Collecting server deployment inputs"
  log_info "For prompts with a default value, press Enter to accept it."
  ORG_NAME="$(prompt_required_with_context "ORG_NAME" "${ORG_NAME:-}" "${org_example}" "Organization identifier used in peer/orderer identities and policy values.")"
  SUB_DOMAIN="$(prompt_required_with_context "SUB_DOMAIN" "${SUB_DOMAIN:-}" "${sub_domain_example}" "Base DNS suffix for generated hostnames.")"
  ENVIRONMENT="$(prompt_required_with_context "ENVIRONMENT" "${ENVIRONMENT:-}" "${environment_example}" "Environment folder namespace used in generated paths and artifacts.")"
  set_derived_defaults

  orderer_tls_ca_example="${REPO_ROOT}/ca-ishareord.pem"
  anchor_peer_example="peer0.${ORG_NAME}.${SUB_DOMAIN}"
  chaincode_policy_example="OR('${ORG_NAME}.member')"
  satellite_admin_email_example="satelliteadmin@${SUB_DOMAIN}"
  peer_admin_msp_example="${REPO_ROOT}/app/${ENVIRONMENT}/${ORG_NAME}/crypto/peerOrganizations/${ORG_NAME}.${SUB_DOMAIN}/users/Admin@${ORG_NAME}.${SUB_DOMAIN}/msp"
  channel_default="${CHANNEL_NAME:-appchannel}"
  anchor_peer_default="${ANCHOR_PEER_HOSTNAME:-peer0.${ORG_NAME}.${SUB_DOMAIN}}"
  anchor_peer_port_default="${ANCHOR_PEER_PORT_NUMBER:-7051}"
  chaincode_name_default="${CHAINCODE_NAME:-isharecode}"
  chaincode_version_default="${CHAINCODE_VERSION:-v1}"
  chaincode_sequence_default="${CHAINCODE_SEQUENCE:-1}"
  chaincode_policy_default="${CHAINCODE_POLICY:-OR('${ORG_NAME}.member')}"
  peer_admin_msp_default="${PEER_ADMIN_MSP_DIR:-${REPO_ROOT}/app/${ENVIRONMENT}/${ORG_NAME}/crypto/peerOrganizations/${ORG_NAME}.${SUB_DOMAIN}/users/Admin@${ORG_NAME}.${SUB_DOMAIN}/msp}"
  orderer_tls_ca_default="${ORDERER_TLS_CA_CERT:-${REPO_ROOT}/ca-ishareord.pem}"
  satellite_admin_username_default="${SATELLITE_ADMIN_USERNAME:-satelliteadmin}"
  satellite_admin_email_default="${SATELLITE_ADMIN_EMAIL:-satelliteadmin@${SUB_DOMAIN}}"

  ORDERER_ADDRESS="$(prompt_required_with_context "ORDERER_ADDRESS" "${ORDERER_ADDRESS:-}" "${orderer_address_example}" "Remote orderer endpoint used by channel and chaincode lifecycle operations.")"
  ORDERER_TLS_CA_CERT="$(prompt_required_with_context "ORDERER_TLS_CA_CERT" "${orderer_tls_ca_default}" "${orderer_tls_ca_example}" "CA certificate file used to trust the remote orderer TLS certificate.")"
  CHANNEL_NAME="$(prompt_required_with_context "CHANNEL_NAME" "${channel_default}" "${channel_example}" "Fabric channel to join and use for ledger and chaincode operations.")"
  ANCHOR_PEER_HOSTNAME="$(prompt_required_with_context "ANCHOR_PEER_HOSTNAME" "${anchor_peer_default}" "${anchor_peer_example}" "Peer hostname published as your org anchor peer on the channel.")"
  ANCHOR_PEER_PORT_NUMBER="$(prompt_required_with_context "ANCHOR_PEER_PORT_NUMBER" "${anchor_peer_port_default}" "7051" "Anchor peer service port.")"
  CHAINCODE_NAME="$(prompt_required_with_context "CHAINCODE_NAME" "${chaincode_name_default}" "${chaincode_name_example}" "Chaincode package name expected by the shared network.")"
  CHAINCODE_VERSION="$(prompt_required_with_context "CHAINCODE_VERSION" "${chaincode_version_default}" "${chaincode_version_example}" "Chaincode version expected by the shared network.")"
  CHAINCODE_SEQUENCE="$(prompt_required_with_context "CHAINCODE_SEQUENCE" "${chaincode_sequence_default}" "${chaincode_sequence_example}" "Chaincode sequence expected by the shared network.")"
  CHAINCODE_POLICY="$(prompt_required_with_context "CHAINCODE_POLICY" "${chaincode_policy_default}" "${chaincode_policy_example}" "Endorsement policy used during chaincode approval.")"
  PEER_ADMIN_MSP_DIR="$(prompt_required_with_context "PEER_ADMIN_MSP_DIR" "${peer_admin_msp_default}" "${peer_admin_msp_example}" "Admin MSP path used by peer CLI to sign channel and lifecycle operations.")"

  PARTY_ID="$(prompt_required_with_context "PARTY_ID" "${PARTY_ID:-}" "${party_id_example}" "iSHARE party identifier used by app middleware.")"
  PARTY_NAME="$(prompt_required_with_context "PARTY_NAME" "${PARTY_NAME:-}" "${party_name_example}" "Display/legal organization name used by app middleware.")"
  UIHostName="$(prompt_required_with_context "UIHostName" "${UIHostName:-}" "${ui_hostname_example}" "Public hostname for the UI entrypoint.")"
  MiddlewareHostName="$(prompt_required_with_context "MiddlewareHostName" "${MiddlewareHostName:-}" "${mw_hostname_example}" "Public hostname for middleware APIs.")"
  KeycloakHostName="$(prompt_required_with_context "KeycloakHostName" "${KeycloakHostName:-}" "${kc_hostname_example}" "Public hostname for Keycloak identity provider.")"
  SMTP_PORT="$(prompt_required_with_context "SMTP_PORT" "${SMTP_PORT:-}" "${smtp_port_example}" "SMTP port used for notification emails.")"
  SMTP_HOST="$(prompt_required_with_context "SMTP_HOST" "${SMTP_HOST:-}" "${smtp_host_example}" "SMTP server hostname for notification emails.")"
  SMTP_USER="$(prompt_required_with_context "SMTP_USER" "${SMTP_USER:-}" "${smtp_user_example}" "SMTP username used by middleware mailer.")"
  SMTP_PASSWORD="$(prompt_required_secret_with_context "SMTP_PASSWORD" "${SMTP_PASSWORD:-}" "${smtp_password_example}" "SMTP password used by middleware mailer.")"
  DISPLAY_NAME="$(prompt_required_with_context "DISPLAY_NAME" "${DISPLAY_NAME:-}" "${display_name_example}" "Email display name shown in outbound notifications.")"
  SATELLITE_ADMIN_USERNAME="$(prompt_required_with_context "SATELLITE_ADMIN_USERNAME" "${satellite_admin_username_default}" "${satellite_admin_username_example}" "Initial Keycloak user that will receive the SatelliteAdmin portal role.")"
  SATELLITE_ADMIN_EMAIL="$(prompt_required_with_context "SATELLITE_ADMIN_EMAIL" "${satellite_admin_email_default}" "${satellite_admin_email_example}" "Email address for the initial SatelliteAdmin portal user.")"
  SATELLITE_ADMIN_PASSWORD="$(prompt_required_secret_with_context "SATELLITE_ADMIN_PASSWORD" "${SATELLITE_ADMIN_PASSWORD:-}" "${satellite_admin_password_example}" "Password for the initial SatelliteAdmin portal user. Change it after first login.")"

  validate_required_env
  write_env_file
  log_info "Wrote ${ENV_FILE}"
}

stage_preflight() {
  local stage="preflight"
  local missing=()
  local cmd
  local compose_version_raw
  local compose_version
  local compose_major
  local plugin_compose_version_raw
  local plugin_compose_version
  local plugin_compose_major
  local compose_wrapper
  local server_min_api
  local requested_api

  if is_debian_like; then
    report_pass "${stage}" "OS check" "Debian-like distribution detected"
  else
    report_fail "${stage}" "OS check" "Only Debian/Ubuntu supported"
    die "Server installer supports Debian/Ubuntu VMs only"
  fi

  if [[ -d "${REPO_ROOT}/scripts" ]]; then
    report_pass "${stage}" "Repository layout" "scripts/ directory present"
  else
    report_fail "${stage}" "Repository layout" "Missing ${REPO_ROOT}/scripts"
    die "Missing scripts directory at ${REPO_ROOT}/scripts"
  fi

  if [[ -f "${REPO_ROOT}/prerequsites.sh" ]]; then
    report_pass "${stage}" "Prerequisite script" "prerequsites.sh found"
  else
    report_fail "${stage}" "Prerequisite script" "Missing ${REPO_ROOT}/prerequsites.sh"
    die "Missing prerequisite installer at ${REPO_ROOT}/prerequsites.sh"
  fi

  for cmd in bash docker jq openssl curl; do
    if require_cmd "$cmd"; then
      report_pass "${stage}" "Command available" "${cmd}"
    else
      report_fail "${stage}" "Command available" "${cmd} not found"
      missing+=("$cmd")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_warn "Missing prerequisites: ${missing[*]}"
    if [[ "${NON_INTERACTIVE}" == "true" ]]; then
      report_fail "${stage}" "Missing prerequisites" "${missing[*]}"
      die "Install missing prerequisites first, then rerun"
    fi
    if confirm "Run prerequsites.sh now?"; then
      report_warn "${stage}" "Auto-fix" "Running prerequsites.sh by user confirmation"
      (cd "${REPO_ROOT}" && bash ./prerequsites.sh)
      report_warn "${stage}" "Auto-fix result" "Prerequisite script completed; rerun installer"
      die "Prerequisite script finished. Re-run installer (use --resume if desired)."
    fi
    report_fail "${stage}" "Prerequisite confirmation" "User declined auto-run"
    die "Cannot continue without prerequisites."
  fi

  if ! docker info >/dev/null 2>&1; then
    report_fail "${stage}" "Docker daemon access" "docker info failed for current user"
    die "Docker daemon is not reachable for current user."
  fi
  report_pass "${stage}" "Docker daemon access" "docker info succeeded"

  plugin_compose_version_raw="$(docker compose version 2>/dev/null | head -n 1 || true)"
  plugin_compose_version="$(extract_semver "${plugin_compose_version_raw}")"
  plugin_compose_major="${plugin_compose_version%%.*}"
  if [[ -n "${plugin_compose_version}" && "${plugin_compose_major}" -ge 2 ]]; then
    mkdir -p "${INSTALL_BIN_DIR}"
    compose_wrapper="${INSTALL_BIN_DIR}/docker-compose"
    cat >"${compose_wrapper}" <<'EOF'
#!/usr/bin/env sh
exec docker compose "$@"
EOF
    chmod +x "${compose_wrapper}"
    case ":${PATH}:" in
      *":${INSTALL_BIN_DIR}:"*) ;;
      *) PATH="${INSTALL_BIN_DIR}:${PATH}" ;;
    esac
    export PATH
    report_pass "${stage}" "Compose implementation" "docker compose plugin v${plugin_compose_version} (docker-compose wrapper active)"
  else
    if ! require_cmd docker-compose; then
      report_fail "${stage}" "Compose implementation" "Neither docker compose plugin nor docker-compose command is available"
      die "Docker Compose v2 is required. Install docker compose plugin."
    fi

    compose_version_raw="$(docker-compose version 2>&1 | head -n 1)"
    compose_version="$(extract_semver "${compose_version_raw}")"
    if [[ -z "${compose_version}" ]]; then
      report_fail "${stage}" "docker-compose version" "Unable to parse version from: ${compose_version_raw}"
      die "Unable to determine docker-compose version. Install Docker Compose v2."
    fi
    compose_major="${compose_version%%.*}"
    if [[ "${compose_major}" -lt 2 ]]; then
      report_fail "${stage}" "docker-compose version" "Detected v${compose_version}; v2+ required"
      die "docker-compose v1 detected. Install docker compose plugin (v2) or replace docker-compose with a v2-compatible wrapper."
    fi
    report_pass "${stage}" "Compose implementation" "docker-compose v${compose_version}"
  fi

  if [[ -n "${DOCKER_API_VERSION:-}" ]]; then
    server_min_api="$(docker version --format '{{.Server.MinAPIVersion}}' 2>/dev/null || true)"
    requested_api="$(normalize_version "${DOCKER_API_VERSION}")"
    if [[ -n "${server_min_api}" && -n "${requested_api}" ]]; then
      if version_lt "${requested_api}" "$(normalize_version "${server_min_api}")"; then
        report_fail "${stage}" "DOCKER_API_VERSION" "Requested ${DOCKER_API_VERSION}, server minimum ${server_min_api}"
        die "DOCKER_API_VERSION is lower than the Docker daemon minimum API. Unset DOCKER_API_VERSION or use a newer value."
      fi
      report_pass "${stage}" "DOCKER_API_VERSION" "Requested ${DOCKER_API_VERSION}, server minimum ${server_min_api}"
    else
      report_warn "${stage}" "DOCKER_API_VERSION" "Set to '${DOCKER_API_VERSION}', unable to validate against server minimum API"
    fi
  fi
}

stage_env() {
  local stage="env"
  local required_key
  local orderer_ca_path

  if [[ -f "${ENV_FILE}" ]]; then
    log_info "Loading existing env file: ${ENV_FILE}"
    report_pass "${stage}" "Env source" "Using existing env file ${ENV_FILE}"
    load_env_file
    set_defaults
    set_derived_defaults
  else
    if [[ -f "${EXAMPLE_ENV_FILE}" ]]; then
      report_warn "${stage}" "Env source" "No env file found; interactive prompts will show examples from ${EXAMPLE_ENV_FILE} and prefill common participant-registry defaults"
    else
      report_warn "${stage}" "Env source" "No env file found; interactive prompts will require manual input except built-in defaults for common participant-registry values"
    fi
    set_defaults
    set_derived_defaults
  fi

  if [[ "${NON_INTERACTIVE}" == "true" ]]; then
    if [[ ! -f "${ENV_FILE}" ]]; then
      report_fail "${stage}" "Non-interactive env file" "Missing ${ENV_FILE}"
      die "Non-interactive mode requires env file: ${ENV_FILE}"
    fi
    load_env_file
    validate_required_env
    write_env_file
  else
    interactive_capture_env
  fi

  if [[ -z "${SATELLITE_ADMIN_PASSWORD:-}" ]]; then
    SATELLITE_ADMIN_PASSWORD="$(openssl rand -base64 24 | tr -d '\n' | tr -d '/+=' | cut -c1-20)Aa1!"
    report_warn "${stage}" "SATELLITE_ADMIN_PASSWORD" "Not set; generated a temporary password and wrote it to ${ENV_FILE}"
    log_warn "SATELLITE_ADMIN_PASSWORD was not set; generated a temporary password. Update it after first login."
    write_env_file
  fi

  validate_required_env
  validate_env_format_with_report "${stage}"
  for required_key in "${REQUIRED_ENV_VARS[@]}"; do
    report_pass "${stage}" "Required variable" "${required_key} is set"
  done
  if [[ -n "${CC_PACKAGE_ID:-}" ]]; then
    report_pass "${stage}" "Optional variable" "CC_PACKAGE_ID override is set"
  else
    report_pass "${stage}" "Optional variable" "CC_PACKAGE_ID override not set (auto-detect will be used)"
  fi
  report_pass "${stage}" "ORG_NAME format" "${ORG_NAME}"
  report_pass "${stage}" "Endpoints" "UI=${UIHostName}, MW=${MiddlewareHostName}, KC=${KeycloakHostName}"

  orderer_ca_path="$(resolve_path "${REPO_ROOT}" "${ORDERER_TLS_CA_CERT}")"
  if [[ -f "${orderer_ca_path}" ]]; then
    report_pass "${stage}" "ORDERER_TLS_CA_CERT path" "${orderer_ca_path}"
  else
    report_warn "${stage}" "ORDERER_TLS_CA_CERT path" "Not present yet: ${orderer_ca_path} (required before join-network)"
  fi

  report_pass "${stage}" "Env file written" "${ENV_FILE}"
}

stage_fabric_base() {
  local stage="fabric-base"
  local ca_compose_file
  local peer_compose_file
  local tls_ca_cert

  load_env_file

  run_script_with_report "${stage}" "fabric-ca-cert.sh"
  run_script_with_report "${stage}" "fabric-ca.sh"
  run_script_with_report "${stage}" "registerAndEnroll.sh"
  run_script_with_report "${stage}" "peer.sh"

  tls_ca_cert="${REPO_ROOT}/openssl/tls-rca/${ENVIRONMENT}/${ORG_NAME}/certs/ca.${ORG_NAME}.${SUB_DOMAIN}-cert.pem"
  report_assert_file "${stage}" "${tls_ca_cert}" "Fabric CA root cert"

  ca_compose_file="${REPO_ROOT}/hlf/${ENVIRONMENT}/${ORG_NAME}/fabric-ca/docker-compose-fabric-ca.yaml"
  peer_compose_file="${REPO_ROOT}/hlf/${ENVIRONMENT}/${ORG_NAME}/peers/docker-compose-hlf.yaml"
  report_assert_file "${stage}" "${ca_compose_file}" "Fabric CA compose file"
  report_assert_file "${stage}" "${peer_compose_file}" "Peer compose file"
  report_assert_compose_running "${stage}" "${ca_compose_file}" "Fabric CA services running"
  report_assert_compose_running "${stage}" "${peer_compose_file}" "Peer services running"
}

stage_org_artifact() {
  local stage="org-artifact"
  local org_definition_file
  local gate_note

  load_env_file
  run_script_with_report "${stage}" "orgDefinition.sh"
  org_definition_file="${REPO_ROOT}/hlf/${ENVIRONMENT}/${ORG_NAME}/${ORG_NAME}.json"
  report_assert_nonempty_file "${stage}" "${org_definition_file}" "Org definition artifact"
  log_info "Org definition should now be available in hlf/<ENVIRONMENT>/<ORG_NAME>/<ORG_NAME>.json"

  gate_note="Send ${org_definition_file} securely to iSHARE Foundation for channel onboarding."
  set_external_gate "EXT_ORG_JSON" "waiting_external" "${gate_note}"
  report_warn "${stage}" "External gate EXT-02 org JSON handoff" "${gate_note}"

  if [[ "${NON_INTERACTIVE}" == "true" ]]; then
    report_fail "${stage}" "External gate EXT-02 org JSON handoff" "Pending external action in non-interactive mode"
    die "External requirement pending: send ${org_definition_file} to iSHARE Foundation, then rerun: $(resume_command)"
  fi

  request_external_pause_after_stage "EXT-02" "${gate_note}"
}

stage_join_network() {
  local stage="join-network"
  local orderer_ca
  local genesis_block
  local channel_tx
  local channel_block
  local anchor_update
  local org_definition_file
  local org_json_status
  local foundation_note

  load_env_file
  orderer_ca="$(resolve_path "${REPO_ROOT}" "${ORDERER_TLS_CA_CERT}")"
  genesis_block="${REPO_ROOT}/middleware/genesis.block"
  channel_tx="${REPO_ROOT}/middleware/isharechannel.tx"
  org_definition_file="${REPO_ROOT}/hlf/${ENVIRONMENT}/${ORG_NAME}/${ORG_NAME}.json"

  org_json_status="$(get_external_gate_status "EXT_ORG_JSON")"
  if [[ "${org_json_status}" != "validated" ]]; then
    if [[ "${NON_INTERACTIVE}" == "true" ]]; then
      set_external_gate "EXT_ORG_JSON" "waiting_external" "Pending confirmation that ${org_definition_file} was sent"
      report_fail "${stage}" "External gate EXT-02 org JSON handoff" "Pending in non-interactive mode"
      die "External requirement pending: confirm ${org_definition_file} was sent to iSHARE Foundation, then rerun: $(resume_stage_command "${stage}")"
    fi

    report_warn "${stage}" "External gate EXT-02 org JSON handoff" "Confirm org definition was sent: ${org_definition_file}"
    if confirm "Have you securely sent ${org_definition_file} to iSHARE Foundation?"; then
      set_external_gate "EXT_ORG_JSON" "validated" "Operator confirmed org JSON handoff"
      report_pass "${stage}" "External gate EXT-02 org JSON handoff" "Confirmed by operator"
    else
      set_external_gate "EXT_ORG_JSON" "waiting_external" "Awaiting org JSON handoff"
      wait_for_external_and_return "EXT-02" "Send ${org_definition_file} to iSHARE Foundation."
      return 0
    fi
  fi

  require_external_file_or_die \
    "${stage}" \
    "EXT_FOUNDATION_PACKAGE" \
    "${orderer_ca}" \
    "ORDERER_TLS_CA_CERT file" \
    "Join operations require the ordering service TLS CA certificate." \
    "Copy ca-ishareord.pem and set ORDERER_TLS_CA_CERT in ${ENV_FILE}"

  require_external_file_or_die \
    "${stage}" \
    "EXT_FOUNDATION_PACKAGE" \
    "${genesis_block}" \
    "middleware/genesis.block" \
    "Join and middleware network sync require foundation-provided genesis.block." \
    "Copy genesis.block to ${REPO_ROOT}/middleware/genesis.block"

  require_external_file_or_die \
    "${stage}" \
    "EXT_FOUNDATION_PACKAGE" \
    "${channel_tx}" \
    "middleware/isharechannel.tx" \
    "Join and middleware network sync require foundation-provided isharechannel.tx." \
    "Copy isharechannel.tx to ${REPO_ROOT}/middleware/isharechannel.tx"

  foundation_note="Foundation package present (ca-ishareord.pem, genesis.block, isharechannel.tx)."
  set_external_gate "EXT_FOUNDATION_PACKAGE" "validated" "${foundation_note}"
  report_pass "${stage}" "External gate EXT-03 foundation package" "${foundation_note}"

  if [[ "${NON_INTERACTIVE}" != "true" ]]; then
    confirm "Have you completed onboarding and received required network values/artifacts?" || \
      die "Join stage aborted by user."
    report_pass "${stage}" "Onboarding confirmation" "User confirmed artifacts and network onboarding"
  else
    report_warn "${stage}" "Onboarding confirmation" "Skipped prompt in non-interactive mode"
  fi

  report_pass "${stage}" "Chaincode package ID strategy" "approveChaincode.sh resolves package ID dynamically (CC_PACKAGE_ID override supported)"

  if ! run_script_with_report "${stage}" "joinchannel.sh"; then
    handle_join_network_script_failure "${stage}" "joinchannel.sh"
  fi
  set_external_gate "EXT_CHANNEL_ADMISSION" "validated" "joinchannel.sh succeeded; channel access confirmed"

  if ! run_script_with_report "${stage}" "anchorPeer.sh"; then
    handle_join_network_script_failure "${stage}" "anchorPeer.sh"
  fi

  run_script_with_report "${stage}" "installChaincode.sh"
  run_script_with_report "${stage}" "approveChaincode.sh"
  run_script_with_report "${stage}" "chaincode.sh"
  run_script_with_report "${stage}" "explorer.sh"

  channel_block="${REPO_ROOT}/channelops/${CHANNEL_NAME}.pb"
  anchor_update="${REPO_ROOT}/channelops/config_update_in_envelope.pb"
  report_assert_nonempty_file "${stage}" "${channel_block}" "Fetched channel block"
  report_assert_nonempty_file "${stage}" "${anchor_update}" "Anchor update envelope"
}

stage_app_deploy() {
  local stage="app-deploy"
  local tls_crt="${REPO_ROOT}/ssl/tls.crt"
  local tls_key="${REPO_ROOT}/ssl/tls.key"
  local jwt_pub="${REPO_ROOT}/jwt-rsa/jwtRSA256-public.pem"
  local jwt_priv="${REPO_ROOT}/jwt-rsa/jwtRSA256-private.pem"
  local genesis_block="${REPO_ROOT}/middleware/genesis.block"
  local channel_tx="${REPO_ROOT}/middleware/isharechannel.tx"
  local keycloak_compose
  local middleware_compose
  local ui_compose
  local app_mw_config
  local keycloak_domain

  load_env_file

  require_external_file_or_die \
    "${stage}" \
    "EXT_TLS_MATERIAL" \
    "${tls_crt}" \
    "TLS certificate" \
    "UI/Keycloak ingress requires ssl/tls.crt." \
    "Copy your TLS certificate chain to ${tls_crt}"
  require_external_file_or_die \
    "${stage}" \
    "EXT_TLS_MATERIAL" \
    "${tls_key}" \
    "TLS private key" \
    "UI/Keycloak ingress requires ssl/tls.key." \
    "Copy your TLS private key to ${tls_key}"
  set_external_gate "EXT_TLS_MATERIAL" "validated" "TLS files present"

  require_external_file_or_die \
    "${stage}" \
    "EXT_JWT_MATERIAL" \
    "${jwt_pub}" \
    "JWT public certificate" \
    "Middleware token signing requires jwtRSA256-public.pem." \
    "Copy JWT public cert to ${jwt_pub}"
  require_external_file_or_die \
    "${stage}" \
    "EXT_JWT_MATERIAL" \
    "${jwt_priv}" \
    "JWT private key" \
    "Middleware token signing requires jwtRSA256-private.pem." \
    "Copy JWT private key to ${jwt_priv}"
  set_external_gate "EXT_JWT_MATERIAL" "validated" "JWT key pair present"

  require_external_file_or_die \
    "${stage}" \
    "EXT_FOUNDATION_PACKAGE" \
    "${genesis_block}" \
    "middleware/genesis.block" \
    "Middleware startup mounts genesis.block for blockchain middleware config." \
    "Copy genesis.block to ${genesis_block}"
  require_external_file_or_die \
    "${stage}" \
    "EXT_FOUNDATION_PACKAGE" \
    "${channel_tx}" \
    "middleware/isharechannel.tx" \
    "Middleware startup mounts isharechannel.tx for blockchain middleware config." \
    "Copy isharechannel.tx to ${channel_tx}"

  report_key_permission_warning "${stage}" "${tls_key}" "TLS private key"
  report_key_permission_warning "${stage}" "${jwt_priv}" "JWT private key"
  report_dns_resolution_warning "${stage}" "${UIHostName}" "DNS resolution UIHostName"
  report_dns_resolution_warning "${stage}" "${MiddlewareHostName}" "DNS resolution MiddlewareHostName"
  report_dns_resolution_warning "${stage}" "${KeycloakHostName}" "DNS resolution KeycloakHostName"
  set_external_gate "EXT_APP_DNS" "warned" "DNS checks reported as warning-only"

  report_smtp_connectivity_warning "${stage}" "${SMTP_HOST}" "${SMTP_PORT}"
  set_external_gate "EXT_SMTP" "warned" "SMTP connectivity is warning-only"

  run_script_with_report "${stage}" "keycloak.sh"
  run_script_with_report "${stage}" "middleware.sh"
  app_mw_config="${REPO_ROOT}/middleware/app-mw-config.yaml"
  report_assert_file "${stage}" "${app_mw_config}" "Rendered middleware app config"
  keycloak_domain="$(awk -F': ' '/^[[:space:]]*domain:[[:space:]]*/ {print $2; exit}' "${app_mw_config}" | tr -d '\r')"
  if [[ -z "${keycloak_domain}" ]]; then
    report_fail "${stage}" "Middleware Keycloak domain" "Unable to parse keyCloakConfig.domain from ${app_mw_config}"
    die "Unable to parse keyCloakConfig.domain from ${app_mw_config}"
  fi
  if [[ "${keycloak_domain}" == *":8443"* ]]; then
    report_fail "${stage}" "Middleware Keycloak domain" "Unsupported value '${keycloak_domain}' in ${app_mw_config}; use https://${KeycloakHostName} without :8443"
    die "Middleware keycloak domain must not include :8443; expected https://${KeycloakHostName}"
  fi
  report_pass "${stage}" "Middleware Keycloak domain" "${keycloak_domain}"
  run_script_with_report "${stage}" "deployUI.sh"
  run_script_with_report "${stage}" "provisionSatelliteAdmin.sh"

  keycloak_compose="${REPO_ROOT}/keycloak/keycloak-docker-compose.yaml"
  middleware_compose="${REPO_ROOT}/middleware/docker-compose-mw.yaml"
  ui_compose="${REPO_ROOT}/ui/docker-compose-ui.yaml"

  report_assert_file "${stage}" "${keycloak_compose}" "Rendered keycloak compose"
  report_assert_file "${stage}" "${middleware_compose}" "Rendered middleware compose"
  report_assert_file "${stage}" "${ui_compose}" "Rendered UI compose"
  report_assert_compose_running "${stage}" "${keycloak_compose}" "Keycloak stack running"
  report_assert_compose_running "${stage}" "${middleware_compose}" "Middleware stack running"
  report_assert_compose_running "${stage}" "${ui_compose}" "UI stack running"

  report_pass "${stage}" "Endpoint summary" "https://${UIHostName} | https://${MiddlewareHostName} | https://${KeycloakHostName}:8443/auth"
}

run_stage() {
  local key="$1"
  local title="$2"
  local fn="$3"
  CURRENT_STAGE="${key}"

  if [[ -n "${TARGET_STAGE}" && "${TARGET_STAGE}" != "${key}" ]]; then
    return
  fi

  if [[ "${RESUME}" == "true" && "${FORCE_STAGE}" != "${key}" ]] && has_checkpoint "${STATE_DIR}" "${key}"; then
    log_info "Skipping completed stage: ${key}"
    report_skip "${key}" "Stage execution" "Skipped due to --resume checkpoint"
    write_state_file "RUNNING" "Stage ${key} skipped due to checkpoint"
    return
  fi

  TARGET_STAGE_RAN=true
  log_info "=== Stage: ${title} (${key}) ==="
  report_stage_header "${key}" "${title}"
  write_state_file "RUNNING" "Executing stage ${key}"
  STAGE_PAUSE_REQUESTED=false
  "${fn}"
  if [[ "${STAGE_PAUSE_REQUESTED}" == "true" ]]; then
    report_warn "${key}" "Stage execution" "Paused for external requirement"
    return 0
  fi
  report_pass "${key}" "Stage execution" "completed"
  mark_checkpoint "${STATE_DIR}" "${key}"
  write_state_file "RUNNING" "Completed stage ${key}"
}

on_exit() {
  local exit_code=$?
  if [[ -n "${REPORT_FILE}" && -f "${REPORT_FILE}" ]]; then
    if [[ "${exit_code}" -eq 0 && "${FINAL_STATUS_OVERRIDE}" == "WAITING_EXTERNAL" ]]; then
      printf "\nFinal status: WAITING_EXTERNAL (%s)\n" "${FINAL_STATUS_MESSAGE}" >>"${REPORT_FILE}"
    elif [[ "${exit_code}" -eq 0 ]]; then
      printf "\nFinal status: SUCCESS\n" >>"${REPORT_FILE}"
    else
      printf "\nFinal status: FAILED (exit code %s)\n" "${exit_code}" >>"${REPORT_FILE}"
    fi
  fi

  if [[ "${exit_code}" -eq 0 && "${FINAL_STATUS_OVERRIDE}" == "WAITING_EXTERNAL" ]]; then
    write_state_file "WAITING_EXTERNAL" "${FINAL_STATUS_MESSAGE}"
    rm -f "${LAST_ERROR_FILE}"
    log_warn "Installer paused: ${FINAL_STATUS_MESSAGE}"
    log_info "Resume command: $(resume_command)"
    log_info "Validation report: ${REPORT_FILE}"
  elif [[ "${exit_code}" -eq 0 ]]; then
    write_state_file "SUCCESS" "Installer completed successfully"
    rm -f "${LAST_ERROR_FILE}"
    log_info "Validation report: ${REPORT_FILE}"
  else
    write_state_file "FAILED" "Installer failed"
    write_last_error_file "${exit_code}" "Installer failed during stage ${CURRENT_STAGE}"
    log_error "Installer failed. Validation report: ${REPORT_FILE}"
  fi
}

main() {
  parse_args "$@"

  if [[ "${SHOW_EXTERNAL_GATES}" == "true" ]]; then
    init_state_dir "${STATE_DIR}"
    init_external_state
    print_external_gates
    exit 0
  fi

  if [[ -n "${TARGET_STAGE}" ]] && ! is_valid_stage "${TARGET_STAGE}"; then
    die "Invalid --stage value: ${TARGET_STAGE}"
  fi
  if [[ -n "${FORCE_STAGE}" ]] && ! is_valid_stage "${FORCE_STAGE}"; then
    die "Invalid --force-stage value: ${FORCE_STAGE}"
  fi

  init_report
  trap on_exit EXIT

  init_state_dir "${STATE_DIR}"
  init_external_state
  write_state_file "RUNNING" "Installer initialized"
  if [[ "${RESET_STATE}" == "true" ]]; then
    clear_checkpoints "${STATE_DIR}"
    rm -f "${EXTERNAL_STATE_FILE}"
    init_external_state
    write_state_file "RUNNING" "Checkpoints cleared via --reset-state"
    log_info "Cleared checkpoints in ${STATE_DIR}"
  fi

  run_stage "preflight" "Bootstrap/Preflight" stage_preflight
  if [[ "${INSTALLER_PAUSED}" == "true" ]]; then
    return 0
  fi
  run_stage "env" "Input/Env Materialization" stage_env
  if [[ "${INSTALLER_PAUSED}" == "true" ]]; then
    return 0
  fi
  run_stage "fabric-base" "Fabric Base Bring-up" stage_fabric_base
  if [[ "${INSTALLER_PAUSED}" == "true" ]]; then
    return 0
  fi
  run_stage "org-artifact" "Org Registration Artifact" stage_org_artifact
  if [[ "${INSTALLER_PAUSED}" == "true" ]]; then
    return 0
  fi
  if [[ "${PAUSE_AFTER_STAGE}" == "true" ]]; then
    FINAL_STATUS_OVERRIDE="WAITING_EXTERNAL"
    FINAL_STATUS_MESSAGE="${PAUSE_REASON}"
    INSTALLER_PAUSED=true
    write_state_file "WAITING_EXTERNAL" "${PAUSE_REASON}"
    log_warn "External gate ${PAUSE_GATE_ID} is waiting: ${PAUSE_REASON}"
    log_info "Resume command: $(resume_command)"
    return 0
  fi
  run_stage "join-network" "Join Shared Network" stage_join_network
  if [[ "${INSTALLER_PAUSED}" == "true" ]]; then
    return 0
  fi
  run_stage "app-deploy" "App Layer Deploy" stage_app_deploy
  if [[ "${INSTALLER_PAUSED}" == "true" ]]; then
    return 0
  fi

  if [[ -n "${TARGET_STAGE}" && "${TARGET_STAGE_RAN}" != "true" ]]; then
    die "Requested stage was not executed: ${TARGET_STAGE}"
  fi

  log_info "Server installer flow complete."
}

main "$@"
