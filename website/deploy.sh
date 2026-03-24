#!/usr/bin/env bash
set -euo pipefail

REMOTE_HOST="${REMOTE_HOST:-194.195.248.217}"
REMOTE_USER="${REMOTE_USER:-svc_epstein}"
REMOTE_PORT="${REMOTE_PORT:-22}"
REMOTE_APP_DIR="/var/www/piday.glasscode.academy/app"
REMOTE_SERVICE_USER="${REMOTE_SERVICE_USER:-svc_epstein}"
SSH_KEY_PATH="${REMOTE_SSH_KEY_PATH:-$HOME/.ssh/id_epstein_prod_ed25519}"
SKIP_QUALITY=0
SKIP_VERIFY=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-quality) SKIP_QUALITY=1; shift ;;
    --skip-verify) SKIP_VERIFY=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

SSH_OPTS=(-p "$REMOTE_PORT" -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new)
if [[ -f "$SSH_KEY_PATH" ]]; then
  SSH_OPTS+=(-i "$SSH_KEY_PATH")
fi

remote_ssh() {
  ssh "${SSH_OPTS[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "$@"
}

remote_rsync() {
  rsync -avz --delete -e "ssh ${SSH_OPTS[*]}" "$@"
}

ssh_error_hint() {
  cat >&2 <<EOF
✗ Unable to connect to ${REMOTE_USER}@${REMOTE_HOST} over SSH.
  Check that the deploy key is a valid private key, is loaded without CRLF escaping issues,
  and that the server authorizes it for ${REMOTE_USER}.
EOF
}

if [[ "$SKIP_QUALITY" -ne 1 ]]; then
  ./scripts/quality_gate.sh
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY RUN: would sync build artifacts to $REMOTE_HOST:$REMOTE_APP_DIR and verify production."
  exit 0
fi

if ! remote_ssh "true"; then
  ssh_error_hint
  exit 1
fi

if ! remote_ssh "test -d '$REMOTE_APP_DIR' && test -w '$REMOTE_APP_DIR'"; then
  echo "✗ Remote app directory is missing or not writable: $REMOTE_HOST:$REMOTE_APP_DIR" >&2
  echo "  Create it and grant ${REMOTE_SERVICE_USER} access before retrying." >&2
  exit 1
fi

echo "▸ Deploying to ${REMOTE_USER}@${REMOTE_HOST}..."
remote_rsync ./.next/standalone/ "${REMOTE_USER}@${REMOTE_HOST}:$REMOTE_APP_DIR/"
remote_rsync ./public/ "${REMOTE_USER}@${REMOTE_HOST}:$REMOTE_APP_DIR/public/"
remote_rsync ./.next/static/ "${REMOTE_USER}@${REMOTE_HOST}:$REMOTE_APP_DIR/.next/static/"

if [[ "$SKIP_VERIFY" -ne 1 ]]; then
  ./scripts/post_deploy_verify.sh
fi

echo "✓ Done — https://piday.glasscode.academy"
