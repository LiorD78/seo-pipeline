#!/usr/bin/env bash
# IndexNow ping — Bing, Yandex, Seznam, Naver
# Spec: https://www.indexnow.org/documentation
set -uo pipefail

# Required env: HOST, KEY, URL_LIST
# Optional env: KEY_LOC, FAIL_ON_ERROR

if [ -z "${KEY:-}" ]; then
  echo "ℹ️  IndexNow key empty — skipping"
  exit 0
fi

# Default key location: https://{host}/{key}.txt
if [ -z "${KEY_LOC:-}" ]; then
  KEY_LOC="https://${HOST}/${KEY}.txt"
fi

# Convert URL_LIST (newline-separated) into JSON array
URLS_JSON=$(echo "$URL_LIST" | grep -v '^[[:space:]]*$' | jq -R . | jq -s .)
URL_COUNT=$(echo "$URLS_JSON" | jq 'length')

if [ "$URL_COUNT" = "0" ]; then
  echo "⚠️  url-list is empty — skipping IndexNow"
  exit 0
fi

echo "🔔 IndexNow: pinging $URL_COUNT URL(s) for host=$HOST"

PAYLOAD=$(jq -n \
  --arg host "$HOST" \
  --arg key "$KEY" \
  --arg keyLoc "$KEY_LOC" \
  --argjson urls "$URLS_JSON" \
  '{host: $host, key: $key, keyLocation: $keyLoc, urlList: $urls}')

HTTP_CODE=$(curl -sX POST "https://api.indexnow.org/indexnow" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d "$PAYLOAD" \
  -o /tmp/indexnow_resp.txt \
  -w "%{http_code}")

case "$HTTP_CODE" in
  200|202)
    echo "  ✅ IndexNow accepted (HTTP $HTTP_CODE)"
    ;;
  *)
    echo "  ❌ IndexNow failed (HTTP $HTTP_CODE)"
    cat /tmp/indexnow_resp.txt 2>/dev/null | head -5
    if [ "${FAIL_ON_ERROR:-false}" = "true" ]; then
      exit 1
    fi
    ;;
esac
