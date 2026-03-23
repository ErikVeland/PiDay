#!/usr/bin/env bash
set -euo pipefail

TMP_FILES=()
cleanup() {
  if [ "${#TMP_FILES[@]}" -gt 0 ]; then
    rm -f "${TMP_FILES[@]}"
  fi
}
trap cleanup EXIT

check_url() {
  local name="$1"
  local url="$2"
  local expected_codes="$3"
  local body_pattern="$4"
  local tmp response status body

  tmp="$(mktemp)"
  TMP_FILES+=("$tmp")
  response="$(curl -k -sS --max-time "${CHECK_TIMEOUT:-20}" -o "$tmp" -w 'HTTP_STATUS:%{http_code}' "$url" || true)"
  status="${response##*HTTP_STATUS:}"
  body="$(cat "$tmp")"

  if ! printf '%s' "$expected_codes" | tr ',' '\n' | grep -qx "$status"; then
    printf '❌ %s returned unexpected status %s for %s\n' "$name" "$status" "$url" >&2
    exit 1
  fi

  if [ -n "$body_pattern" ] && ! printf '%s' "$body" | grep -Eq "$body_pattern"; then
    printf '❌ %s returned an unexpected body for %s\n' "$name" "$url" >&2
    exit 1
  fi

  printf '✅ %s OK (%s)\n' "$name" "$status"
}

echo "Checking production sites..."
check_url "piday.glasscode.academy" "https://piday.glasscode.academy/" "200" '<!DOCTYPE html'
check_url "glasscode.academy gateway" "https://glasscode.academy/health" "200" '^ok$'
check_url "glasscode.academy API" "https://glasscode.academy/api/health" "200" '"status"[[:space:]]*:[[:space:]]*"(ok|healthy)"'
check_url "about.glasscode.academy" "https://about.glasscode.academy/en" "200" '<!DOCTYPE html'
check_url "epstein.academy API" "https://epstein.academy/api/health" "200" '"status"[[:space:]]*:[[:space:]]*"ok"'
echo "✅ Production verification passed."
