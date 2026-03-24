#!/usr/bin/env bash
set -euo pipefail

echo "▶ Installing dependencies"
pnpm install --frozen-lockfile

echo "▶ Linting"
pnpm lint --max-warnings=0

echo "▶ Running tests"
pnpm test

echo "▶ Building production bundle"
pnpm build

echo "✅ Quality gate passed"
