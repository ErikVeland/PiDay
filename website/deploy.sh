#!/usr/bin/env bash
set -euo pipefail

echo "▸ Building..."
pnpm build

echo "▸ Deploying to glasscode..."
rsync -avz --delete ./out/ glasscode:/var/www/piday.glasscode.academy/

echo "✓ Done — https://piday.glasscode.academy"
