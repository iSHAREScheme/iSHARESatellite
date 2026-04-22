#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DEBIAN_FRONTEND=noninteractive

if [[ "${EUID}" -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

docker_was_missing=false

ensure_docker_repo() {
  ${SUDO} mkdir -p /etc/apt/keyrings
  if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | ${SUDO} tee /etc/apt/keyrings/docker.asc >/dev/null
    ${SUDO} chmod a+r /etc/apt/keyrings/docker.asc
  fi

  cat <<EOF | ${SUDO} tee /etc/apt/sources.list.d/docker.list >/dev/null
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${VERSION_CODENAME}") stable
EOF
}

ensure_docker() {
  if command -v docker >/dev/null 2>&1 && docker --version >/dev/null 2>&1; then
    echo "Docker is already installed"
  else
    echo "Installing Docker Engine and Compose plugin"
    docker_was_missing=true
    ${SUDO} apt-get update
    ${SUDO} apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    ensure_docker_repo
    ${SUDO} apt-get update
    ${SUDO} apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  fi

  if ! docker compose version >/dev/null 2>&1; then
    echo "Installing Docker Compose plugin"
    ${SUDO} apt-get update
    ${SUDO} apt-get install -y docker-compose-plugin
  fi

  ${SUDO} gpasswd -a "${USER}" docker >/dev/null 2>&1 || true
  docker version
  docker compose version
}

ensure_jq() {
  if command -v jq >/dev/null 2>&1; then
    jq --version
    echo "jq is already installed"
    return
  fi
  echo "Installing jq"
  ${SUDO} apt-get update
  ${SUDO} apt-get install -y jq
}

ensure_fabric_binaries() {
  if [[ -x "${REPO_ROOT}/bin/fabric-ca-client" && -x "${REPO_ROOT}/bin/peer" && -x "${REPO_ROOT}/bin/configtxgen" && -d "${REPO_ROOT}/config" ]]; then
    echo "Fabric binaries already exist"
    return
  fi

  echo "Installing Hyperledger Fabric binaries into ${REPO_ROOT}/bin"
  (
    cd "${REPO_ROOT}"
    curl -fsSL https://raw.githubusercontent.com/hyperledger/fabric/main/scripts/bootstrap.sh | bash -s -- 2.5.4 1.5.7 -d -s
  )
}

ensure_openssl() {
  if openssl version | grep -Eq '^OpenSSL 3\.'; then
    openssl version
    echo "OpenSSL 3.x is already installed"
    return
  fi

  echo "Installing system OpenSSL"
  ${SUDO} apt-get update
  ${SUDO} apt-get install -y openssl
  openssl version
}

configure_docker_daemon() {
  if [[ ! -f "${REPO_ROOT}/templates/daemon.json" ]]; then
    return
  fi
  if [[ ! -f /etc/docker/daemon.json ]]; then
    ${SUDO} cp "${REPO_ROOT}/templates/daemon.json" /etc/docker/daemon.json
    ${SUDO} systemctl restart docker
  fi
}

ensure_docker
ensure_jq
ensure_fabric_binaries
ensure_openssl

if [[ "${docker_was_missing}" == "true" ]]; then
  configure_docker_daemon
fi
