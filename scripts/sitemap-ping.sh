#!/usr/bin/env bash
# Sitemap ping (Google legacy endpoint).
# Note: Google deprecated this endpoint in mid-2023; use GSC API for canonical submission.
# Best-effort only.
set -uo pipefail

# Required env: SITEMAP_URL
# Optional env: FAIL_ON_ERROR

if [ -z "${SITEMAP_URL:-}" ]; then
  echo "ℹ️  sitemap-url empty — skipping"
  exit 0
fi

echo "🗺️  Pinging Google with sitemap: $SITEMAP_URL"

ENCODED=$(printf '%s' "$SITEMAP_URL" | jq -sRr @uri)
HTTP_CODE=$(curl -s "https://www.google.com/ping?sitemap=$ENCODED" \
  -o /dev/null \
  -w "%{http_code}")

case "$HTTP_CODE" in
  200)
    echo "  ✅ Google ping OK"
    ;;
  *)
    echo "  ⚠️  Google ping returned HTTP $HTTP_CODE (legacy endpoint, may be deprecated)"
    if [ "${FAIL_ON_ERROR:-false}" = "true" ]; then
      exit 1
    fi
    ;;
esac
