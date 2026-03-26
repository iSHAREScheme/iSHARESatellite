#!/usr/bin/env bash

# Shared helpers for the server installer flow.

log_ts() {
  date +"%Y-%m-%d %H:%M:%S"
}

log_info() {
  printf "[%s] [INFO] %s\n" "$(log_ts)" "$*"
}

log_warn() {
  printf "[%s] [WARN] %s\n" "$(log_ts)" "$*" >&2
}

log_error() {
  printf "[%s] [ERROR] %s\n" "$(log_ts)" "$*" >&2
}

die() {
  log_error "$*"
  exit 1
}

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1
}

confirm() {
  local prompt="$1"
  local answer
  if [[ "${NON_INTERACTIVE:-false}" == "true" ]]; then
    return 1
  fi
  read -r -p "${prompt} [y/N]: " answer
  case "${answer}" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

prompt_value() {
  local prompt="$1"
  local default_value="$2"
  local input
  if [[ -n "$default_value" ]]; then
    read -r -p "${prompt} [${default_value}]: " input
    if [[ -z "$input" ]]; then
      printf "%s" "$default_value"
      return
    fi
    printf "%s" "$input"
    return
  fi
  read -r -p "${prompt}: " input
  printf "%s" "$input"
}

prompt_secret() {
  local prompt="$1"
  local default_value="$2"
  local input
  if [[ -n "$default_value" ]]; then
    read -r -s -p "${prompt} [hidden, press Enter to keep current]: " input
    printf "\n" >&2
    if [[ -z "$input" ]]; then
      printf "%s" "$default_value"
      return
    fi
    printf "%s" "$input"
    return
  fi
  read -r -s -p "${prompt}: " input
  printf "\n" >&2
  printf "%s" "$input"
}

is_debian_like() {
  if [[ ! -f /etc/os-release ]]; then
    return 1
  fi
  # shellcheck disable=SC1091
  . /etc/os-release
  [[ "${ID:-}" == "debian" || "${ID:-}" == "ubuntu" || "${ID_LIKE:-}" == *"debian"* ]]
}

init_state_dir() {
  local state_dir="$1"
  mkdir -p "${state_dir}/checkpoints"
}

checkpoint_path() {
  local state_dir="$1"
  local stage="$2"
  printf "%s/checkpoints/%s.done" "$state_dir" "$stage"
}

has_checkpoint() {
  local state_dir="$1"
  local stage="$2"
  [[ -f "$(checkpoint_path "$state_dir" "$stage")" ]]
}

mark_checkpoint() {
  local state_dir="$1"
  local stage="$2"
  local path
  path="$(checkpoint_path "$state_dir" "$stage")"
  mkdir -p "$(dirname "$path")"
  date +"%Y-%m-%dT%H:%M:%S%z" >"$path"
}

clear_checkpoints() {
  local state_dir="$1"
  rm -rf "${state_dir}/checkpoints"
  mkdir -p "${state_dir}/checkpoints"
}

shell_quote() {
  # Single-quote safe shell literal.
  local value="$1"
  value=${value//\'/\'\\\'\'}
  printf "'%s'" "$value"
}

run_repo_script() {
  local repo_root="$1"
  local env_file="$2"
  local script_name="$3"

  (
    set -euo pipefail
    export REPO_ROOT="$repo_root"
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
    cd "$repo_root/scripts"
    log_info "Running scripts/${script_name}"
    bash "./${script_name}"
  )
}

resolve_path() {
  local repo_root="$1"
  local path="$2"
  if [[ -z "$path" ]]; then
    printf ""
    return
  fi
  if [[ "$path" = /* ]]; then
    printf "%s" "$path"
    return
  fi
  printf "%s/%s" "$repo_root" "$path"
}
