#!/usr/bin/env bash
set -euo pipefail

PRIVATE_REPOSITORY="${WEBCORE_PRIVATE_REPOSITORY:-git@github.com:craggyh/webcore-wordpress-platform.git}"
PRIVATE_BRANCH="${WEBCORE_PRIVATE_BRANCH:-main}"
KEY="/etc/webcore/github-deploy-key"
PUB="${KEY}.pub"
KNOWN_HOSTS="/etc/webcore/github-known-hosts"
WORK_ROOT="${WEBCORE_BOOTSTRAP_WORK_ROOT:-/var/tmp/webcore-panel-bootstrap}"
LABEL="webcore-panel@$(hostname -s)"

log() { printf '[webcore-bootstrap] %s\n' "$*"; }
fatal() { printf '[webcore-bootstrap] ERROR: %s\n' "$*" >&2; exit 1; }

[[ "${EUID}" -eq 0 ]] || fatal "run as root"
[[ -r /dev/tty && -w /dev/tty ]] || fatal "an interactive terminal is required"

source /etc/os-release
[[ "${ID:-}" == "ubuntu" ]] || fatal "supported OS is Ubuntu 24.04 or 26.04"
case "${VERSION_ID:-}" in
  24.04|26.04) ;;
  *) fatal "supported Ubuntu releases are 24.04 and 26.04; found ${VERSION_ID:-unknown}" ;;
esac

log "installing bootstrap prerequisites"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates git openssh-client curl

install -d -o root -g root -m 0755 /etc/webcore
if [[ ! -s "${KEY}" || ! -s "${PUB}" ]]; then
  log "generating server-specific read-only GitHub deploy key"
  rm -f "${KEY}" "${PUB}"
  ssh-keygen -q -t ed25519 -N '' -C "${LABEL}" -f "${KEY}"
else
  log "reusing existing GitHub deploy key"
fi
chown root:root "${KEY}" "${PUB}"
chmod 0600 "${KEY}"
chmod 0644 "${PUB}"

log "recording GitHub SSH host keys"
tmp_hosts="$(mktemp)"
trap 'rm -f "${tmp_hosts}"' EXIT
ssh-keyscan -t ed25519,ecdsa,rsa github.com >"${tmp_hosts}" 2>/dev/null || fatal "could not retrieve GitHub host keys"
install -o root -g root -m 0644 "${tmp_hosts}" "${KNOWN_HOSTS}"

verify_repository() {
  GIT_SSH_COMMAND="ssh -i ${KEY} -o IdentitiesOnly=yes -o UserKnownHostsFile=${KNOWN_HOSTS} -o StrictHostKeyChecking=yes" \
    git ls-remote "${PRIVATE_REPOSITORY}" "refs/heads/${PRIVATE_BRANCH}" >/dev/null 2>&1
}

if ! verify_repository; then
  cat >/dev/tty <<EOF

Webcore Panel repository access is not configured yet.

Add the following key to the PRIVATE repository as a read-only deploy key:

  Repository: craggyh/webcore-wordpress-platform
  GitHub: Settings -> Deploy keys -> Add deploy key
  Title: ${LABEL}
  Allow write access: OFF

$(cat "${PUB}")

EOF
  read -r -p "Press Enter after the deploy key has been added to GitHub... " _ </dev/tty
fi

log "verifying private repository access"
verify_repository || fatal "repository access failed; confirm the deploy key was added to the private repository"
log "repository access confirmed"

log "cloning Webcore Panel production source"
rm -rf "${WORK_ROOT}"
install -d -o root -g root -m 0700 "${WORK_ROOT}"
GIT_SSH_COMMAND="ssh -i ${KEY} -o IdentitiesOnly=yes -o UserKnownHostsFile=${KNOWN_HOSTS} -o StrictHostKeyChecking=yes" \
  git clone --branch "${PRIVATE_BRANCH}" --single-branch "${PRIVATE_REPOSITORY}" "${WORK_ROOT}/source"

log "starting private production installer"
cd "${WORK_ROOT}/source"
bash installer/install.sh "$@" </dev/tty

log "Webcore Panel installation completed successfully"
log "the private source bootstrap checkout can be removed: ${WORK_ROOT}"
