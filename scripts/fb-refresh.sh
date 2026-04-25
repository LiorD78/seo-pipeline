#!/usr/bin/env bash
# Facebook Open Graph cache refresh via Graph API
# Calls graph.facebook.com/?id={URL}&scrape=true for each URL
set -uo pipefail

# Required env: FB_TOKEN, URL_LIST
# Optional env: FAIL_ON_ERROR

if [ -z "${FB_TOKEN:-}" ]; then
  echo "ℹ️  FB token empty — skipping"
  exit 0
fi

SUCCESS=0
FAILED=0
TOTAL=0

while IFS= read -r URL; do
  # Skip empty lines and whitespace-only lines
  [ -z "${URL// }" ] && continue
  TOTAL=$((TOTAL + 1))

  STATUS=$(curl -sX POST \
    "https://graph.facebook.com/?id=${URL}&scrape=true&access_token=${FB_TOKEN}" \
    -o /tmp/fb_resp.json \
    -w "%{http_code}")

  if [ "$STATUS" = "200" ]; then
    SUCCESS=$((SUCCESS + 1))
    echo "  ✅ $URL"
  else
    FAILED=$((FAILED + 1))
    echo "  ❌ $URL (HTTP $STATUS)"
    cat /tmp/fb_resp.json 2>/dev/null | head -3
  fi
done <<< "$URL_LIST"

echo ""
echo "📘 FB OG refresh: $SUCCESS success, $FAILED failed (of $TOTAL)"

if [ "$FAILED" -gt 0 ] && [ "${FAIL_ON_ERROR:-false}" = "true" ]; then
  exit 1
fi
exit 0
