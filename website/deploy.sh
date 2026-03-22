#!/usr/bin/env bash
set -euo pipefail

REMOTE_HOST="glasscode"
REMOTE_APP_DIR="/var/www/piday.glasscode.academy/app"
REMOTE_SERVICE_USER="${REMOTE_SERVICE_USER:-svc_epstein}"

echo "▸ Building..."
pnpm build

if ! ssh "$REMOTE_HOST" "test -d '$REMOTE_APP_DIR' && test -w '$REMOTE_APP_DIR'"; then
  echo "✗ Remote app directory is missing or not writable: $REMOTE_HOST:$REMOTE_APP_DIR" >&2
  echo "  Create it and grant ${REMOTE_SERVICE_USER} access before retrying." >&2
  exit 1
fi

echo "▸ Deploying to glasscode..."
rsync -avz --delete ./.next/standalone/ "$REMOTE_HOST:$REMOTE_APP_DIR/"
rsync -avz ./public/ "$REMOTE_HOST:$REMOTE_APP_DIR/public/"
rsync -avz ./.next/static/ "$REMOTE_HOST:$REMOTE_APP_DIR/.next/static/"

echo "✓ Done — https://piday.glasscode.academy"
