#!/usr/bin/env bash

set -euo pipefail

. ./utils.sh
. ./global.sh

HLMW_INVOKE_URL="${BOOTSTRAP_HLF_MW_INVOKE_URL:-http://127.0.0.1:4001/api/invoke}"
BOOTSTRAP_STATE_DIR="${REPO_ROOT}/.local-state/bootstrap-registry"
BOOTSTRAP_TMP_DIR="${BOOTSTRAP_STATE_DIR}/tmp"

mkdir -p "${BOOTSTRAP_TMP_DIR}"

require_command() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    fatalln "Required command not found: ${cmd}"
  fi
}

find_identity_cert() {
  local candidate
  local candidates=()

  if [[ -n "${BOOTSTRAP_IDENTITY_CERT_PATH:-}" ]]; then
    if [[ "${BOOTSTRAP_IDENTITY_CERT_PATH}" = /* ]]; then
      candidates+=("${BOOTSTRAP_IDENTITY_CERT_PATH}")
    else
      candidates+=("${REPO_ROOT}/${BOOTSTRAP_IDENTITY_CERT_PATH}")
    fi
  fi

  if [[ -f "${REPO_ROOT}/jwt-rsa/jwtRSA256-public.pem" ]]; then
    candidates+=("${REPO_ROOT}/jwt-rsa/jwtRSA256-public.pem")
  fi

  while IFS= read -r candidate; do
    candidates+=("${candidate}")
  done < <(find "${REPO_ROOT}/jwt-rsa" -maxdepth 2 -type f \
    \( -name "*.cert.pem" -o -name "*.crt" -o -name "*.cert" -o -name "*.pem" \) 2>/dev/null | sort)

  for candidate in "${candidates[@]}"; do
    [[ -f "${candidate}" ]] || continue
    if openssl x509 -in "${candidate}" -noout >/dev/null 2>&1; then
      printf "%s\n" "${candidate}"
      return 0
    fi
  done

  return 1
}

normalize_subject() {
  local cert_path="$1"
  openssl x509 -in "${cert_path}" -noout -subject \
    | sed -e 's/^subject=//' -e 's/^ *//' -e 's/, /,/g'
}

get_cert_fingerprint() {
  local cert_path="$1"
  openssl x509 -in "${cert_path}" -noout -fingerprint -sha256 \
    | sed -e 's/^.*=//' -e 's/://g' \
    | tr '[:upper:]' '[:lower:]'
}

get_cert_date() {
  local cert_path="$1"
  local selector="$2"
  openssl x509 -in "${cert_path}" -noout "-${selector}" \
    | sed -e "s/^${selector}=//"
}

get_cert_der_base64() {
  local cert_path="$1"
  openssl x509 -in "${cert_path}" -outform der | base64 | tr -d '\n'
}

get_org_identifier() {
  local subject="$1"
  printf "%s\n" "${subject}" | sed -n 's/.*organizationIdentifier=\([^,+]*\).*/\1/p'
}

derive_party_id_from_org_identifier() {
  local org_identifier="$1"
  if [[ "${org_identifier}" =~ ^NTR([A-Z][A-Z]).+ ]]; then
    printf "did:ishare:EU.%s.%s\n" "${BASH_REMATCH[1]}" "${org_identifier}"
    return 0
  fi
  return 1
}

write_payload_files() {
  local cert_path="$1"
  local subject="$2"
  local fingerprint="$3"
  local not_before="$4"
  local not_after="$5"
  local cert_value="$6"
  local org_identifier="$7"
  local party_id="$8"
  local party_name="$9"
  local adherence_start="${10}"
  local adherence_end="${11}"

  CERT_PATH="${cert_path}" \
  CERT_SUBJECT="${subject}" \
  CERT_FINGERPRINT="${fingerprint}" \
  CERT_NOT_BEFORE="${not_before}" \
  CERT_NOT_AFTER="${not_after}" \
  CERT_VALUE="${cert_value}" \
  CERT_ORG_IDENTIFIER="${org_identifier}" \
  PARTY_ID_VALUE="${party_id}" \
  PARTY_NAME_VALUE="${party_name}" \
  ADHERENCE_START_DATE="${adherence_start}" \
  ADHERENCE_END_DATE="${adherence_end}" \
  ORG_NAME_VALUE="${ORG_NAME}" \
  python3 - <<'PY'
import json
import os
from pathlib import Path

tmp_dir = Path(os.environ["BOOTSTRAP_TMP_DIR"])
cert_path = Path(os.environ["CERT_PATH"])
cert_pem = cert_path.read_text()

trusted_payload = {
    "subject": os.environ["CERT_SUBJECT"],
    "certificateFingerprint": os.environ["CERT_FINGERPRINT"],
    "validity": "valid",
    "status": "granted",
    "type": "PKIo",
    "certificate": cert_pem,
    "creatorOrg": os.environ["ORG_NAME_VALUE"],
}

participant_payload = {
    "id": os.environ["PARTY_ID_VALUE"],
    "partyId": os.environ["PARTY_ID_VALUE"],
    "partyName": os.environ["PARTY_NAME_VALUE"],
    "adherenceStartdate": os.environ["ADHERENCE_START_DATE"],
    "adherenceEnddate": os.environ["ADHERENCE_END_DATE"],
    "adherenceStatus": "Active",
    "registarSatelliteID": os.environ["PARTY_ID_VALUE"],
    "certificates": [
        {
            "certificate": cert_pem,
            "subjectName": os.environ["CERT_SUBJECT"],
            "type": "PKIo",
            "notBefore": os.environ["CERT_NOT_BEFORE"],
            "notAfter": os.environ["CERT_NOT_AFTER"],
            "enabledFrom": os.environ["CERT_NOT_BEFORE"],
            "activationStatus": "Active",
            "certificateStatus": "Active",
            "certificateValue": os.environ["CERT_VALUE"],
            "certificateFingerprint": os.environ["CERT_FINGERPRINT"],
            "organizationIdentifier": os.environ["CERT_ORG_IDENTIFIER"],
        }
    ],
    "creatorOrg": os.environ["ORG_NAME_VALUE"],
}

(tmp_dir / "trusted-ca-payload.json").write_text(json.dumps(trusted_payload))
(tmp_dir / "participant-payload.json").write_text(json.dumps(participant_payload))
PY
}

invoke_with_payload() {
  local function_name="$1"
  local payload_file="$2"
  local description="$3"
  local request_file="${BOOTSTRAP_TMP_DIR}/request-${function_name}.json"
  local response_file="${BOOTSTRAP_TMP_DIR}/response-${function_name}.json"
  local body_json
  local http_code
  local attempt

  body_json="$(python3 - "${function_name}" "${payload_file}" <<'PY'
import base64
import json
import os
import sys
from pathlib import Path

function_name = sys.argv[1]
payload = json.loads(Path(sys.argv[2]).read_text())
request = {
    "request": {
        "chaincodeID": os.environ.get("CHAINCODE_NAME", "isharecode"),
        "fcn": function_name,
        "args": [base64.b64encode(json.dumps(payload).encode("utf-8")).decode("ascii")],
        "isInit": False,
    },
    "orgs": [],
}
print(json.dumps(request))
PY
)"
  printf "%s" "${body_json}" > "${request_file}"

  for attempt in 1 2 3 4 5; do
    http_code="$(curl -sS -o "${response_file}" -w "%{http_code}" \
      -H "Content-Type: application/json" \
      --data @"${request_file}" \
      "${HLMW_INVOKE_URL}" || true)"

    if [[ "${http_code}" == "200" || "${http_code}" == "201" ]]; then
      if grep -qi "already exist" "${response_file}"; then
        warnln "${description}: already present, continuing"
      else
        successln "${description}: seeded"
      fi
      return 0
    fi

    if grep -qi "already exist" "${response_file}"; then
      warnln "${description}: already present, continuing"
      return 0
    fi

    if [[ "${attempt}" -lt 5 ]]; then
      warnln "${description}: invoke attempt ${attempt} failed (HTTP ${http_code:-n/a}), retrying"
      sleep 4
      continue
    fi
  done

  errorln "${description}: invoke failed"
  if [[ -f "${response_file}" ]]; then
    cat "${response_file}" >&2
    printf "\n" >&2
  fi
  return 1
}

require_command curl
require_command openssl
require_command python3
export BOOTSTRAP_TMP_DIR

identity_cert="$(find_identity_cert)" || fatalln "No X.509 identity certificate found under ${REPO_ROOT}/jwt-rsa. Set BOOTSTRAP_IDENTITY_CERT_PATH to the certificate file used by this satellite."
subject_name="$(normalize_subject "${identity_cert}")"
certificate_fingerprint="$(get_cert_fingerprint "${identity_cert}")"
not_before="$(get_cert_date "${identity_cert}" startdate)"
not_after="$(get_cert_date "${identity_cert}" enddate)"
certificate_value="$(get_cert_der_base64 "${identity_cert}")"
organization_identifier="$(get_org_identifier "${subject_name}")"
derived_party_id=""

if [[ -z "${organization_identifier}" ]]; then
  fatalln "Unable to extract organizationIdentifier from certificate subject: ${subject_name}"
fi

derived_party_id="$(derive_party_id_from_org_identifier "${organization_identifier}" || true)"

bootstrap_party_id="${PARTY_ID:-}"
if [[ -z "${bootstrap_party_id}" ]]; then
  bootstrap_party_id="$(printf "%s" "${derived_party_id}")"
  if [[ -z "${bootstrap_party_id}" ]]; then
    fatalln "Unable to derive PARTY_ID from organizationIdentifier ${organization_identifier}"
  fi
else
  if [[ -n "${derived_party_id}" && "${bootstrap_party_id}" != "${derived_party_id}" ]]; then
    warnln "Configured PARTY_ID (${bootstrap_party_id}) does not match certificate-derived DID (${derived_party_id}); bootstrapping participant with configured PARTY_ID"
  fi
fi

bootstrap_party_name="${PARTY_NAME:-${ORG_NAME}}"
adherence_start_date="$(date -u +%Y-%m-%d)"
adherence_end_date="$(date -u -d '+365 day' +%Y-%m-%d 2>/dev/null || date -u -v+365d +%Y-%m-%d)"

infoln "Bootstrapping trusted CA and self participant for ${bootstrap_party_id}"
infoln "Using identity certificate ${identity_cert}"

write_payload_files \
  "${identity_cert}" \
  "${subject_name}" \
  "${certificate_fingerprint}" \
  "${not_before}" \
  "${not_after}" \
  "${certificate_value}" \
  "${organization_identifier}" \
  "${bootstrap_party_id}" \
  "${bootstrap_party_name}" \
  "${adherence_start_date}" \
  "${adherence_end_date}"

invoke_with_payload "CreateTrustedCA" "${BOOTSTRAP_TMP_DIR}/trusted-ca-payload.json" "Trusted CA bootstrap"
invoke_with_payload "CreateParticipantV2" "${BOOTSTRAP_TMP_DIR}/participant-payload.json" "Self participant bootstrap"

successln "Registry identity bootstrap completed"
