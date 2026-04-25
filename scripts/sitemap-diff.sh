#!/usr/bin/env bash
# Sitemap diff — fetches a sitemap (or sitemap index), parses URLs with
# their <lastmod> values, compares against a state file from the previous
# run, and emits a list of URLs that are NEW or CHANGED.
#
# Output:
#   - Writes the resulting URL list to $OUT_URL_LIST_FILE (one URL per line)
#   - Updates $STATE_FILE in place with the new sitemap snapshot
#   - Sets GitHub Actions outputs: changed-count, total-count
#
# Required env:
#   SITEMAP_URL       Full URL of sitemap.xml or sitemap index
#   STATE_FILE        Path to JSON state file (created if missing)
#   OUT_URL_LIST_FILE Path to write resulting URL list
# Optional env:
#   MAX_URLS              Cap the resulting URL list size (default 10000)
#   FIRST_RUN_LIMIT       On first run (no state), only ping this many URLs (default 100)
#   FAIL_ON_ERROR         true|false (default false)
set -uo pipefail

: "${SITEMAP_URL:?SITEMAP_URL required}"
: "${STATE_FILE:?STATE_FILE required}"
: "${OUT_URL_LIST_FILE:?OUT_URL_LIST_FILE required}"

MAX_URLS="${MAX_URLS:-10000}"
FIRST_RUN_LIMIT="${FIRST_RUN_LIMIT:-100}"
FAIL_ON_ERROR="${FAIL_ON_ERROR:-false}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "🗺️  Fetching sitemap: $SITEMAP_URL"

# ── Helper: fetch a sitemap URL into a file, follow gzip if needed ──────────
fetch_sitemap() {
  local url="$1" out="$2"
  # -L follow redirects, --compressed handles gzip transparently
  if ! curl -sL --compressed --max-time 30 -o "$out" "$url"; then
    echo "  ❌ Failed to fetch: $url" >&2
    return 1
  fi
  # Sanity check: must be XML
  if ! head -c 200 "$out" | grep -q '<'; then
    echo "  ❌ Not XML content: $url" >&2
    return 1
  fi
  return 0
}

# ── Helper: extract <loc> values from sitemap XML ───────────────────────────
extract_locs() {
  local file="$1"
  # Crude but reliable: pull anything inside <loc>...</loc>, strip whitespace
  grep -oE '<loc>[^<]+</loc>' "$file" \
    | sed -E 's#</?loc>##g' \
    | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'
}

# ── Helper: extract <url><loc>+<lastmod> pairs as TSV: url\tlastmod ─────────
extract_url_lastmod() {
  local file="$1"
  # Use python for robust XML parsing — bash regex on multi-line XML is fragile
  python3 - "$file" <<'PYEOF'
import sys, re
from xml.etree import ElementTree as ET

ns = {'sm': 'http://www.sitemaps.org/schemas/sitemap/0.9'}
try:
    tree = ET.parse(sys.argv[1])
except ET.ParseError as e:
    print(f"  XML parse error: {e}", file=sys.stderr)
    sys.exit(1)

root = tree.getroot()
# Strip namespace from tags so we work with both namespaced and bare XML
for el in root.iter():
    el.tag = re.sub(r'^\{[^}]+\}', '', el.tag)

for url_el in root.findall('url'):
    loc_el = url_el.find('loc')
    if loc_el is None or not loc_el.text:
        continue
    loc = loc_el.text.strip()
    lastmod_el = url_el.find('lastmod')
    lastmod = lastmod_el.text.strip() if (lastmod_el is not None and lastmod_el.text) else ''
    print(f"{loc}\t{lastmod}")
PYEOF
}

# ── Step 1: download root sitemap ───────────────────────────────────────────
ROOT_SM="$WORK/root.xml"
if ! fetch_sitemap "$SITEMAP_URL" "$ROOT_SM"; then
  echo "❌ Cannot fetch root sitemap"
  [ "$FAIL_ON_ERROR" = "true" ] && exit 1 || exit 0
fi

# ── Step 2: detect sitemap index vs flat sitemap ────────────────────────────
SUBSITEMAPS=()
if grep -q '<sitemapindex' "$ROOT_SM"; then
  echo "  📚 Sitemap index detected — expanding sub-sitemaps"
  while IFS= read -r sub; do
    [ -z "$sub" ] && continue
    SUBSITEMAPS+=("$sub")
  done < <(extract_locs "$ROOT_SM")
  echo "  Found ${#SUBSITEMAPS[@]} sub-sitemap(s)"
else
  echo "  📄 Flat sitemap detected"
  SUBSITEMAPS=("$SITEMAP_URL")
fi

# ── Step 3: collect URL → lastmod from all sub-sitemaps ─────────────────────
ALL_TSV="$WORK/all.tsv"
> "$ALL_TSV"

for i in "${!SUBSITEMAPS[@]}"; do
  url="${SUBSITEMAPS[$i]}"
  if [ "$url" = "$SITEMAP_URL" ] && [ ${#SUBSITEMAPS[@]} -eq 1 ]; then
    sub_file="$ROOT_SM"
  else
    sub_file="$WORK/sub-$i.xml"
    if ! fetch_sitemap "$url" "$sub_file"; then
      echo "    ⚠️  Skipping unreachable sub-sitemap: $url"
      continue
    fi
  fi
  extract_url_lastmod "$sub_file" >> "$ALL_TSV"
done

TOTAL_COUNT=$(wc -l < "$ALL_TSV" | tr -d ' ')
echo "  📊 Total URLs in sitemap: $TOTAL_COUNT"

if [ "$TOTAL_COUNT" = "0" ]; then
  echo "⚠️  No URLs extracted from sitemap — nothing to do"
  : > "$OUT_URL_LIST_FILE"
  echo "changed-count=0" >> "${GITHUB_OUTPUT:-/dev/null}"
  echo "total-count=0" >> "${GITHUB_OUTPUT:-/dev/null}"
  exit 0
fi

# ── Step 4: build current-state JSON {url: lastmod, ...} ────────────────────
CURRENT_STATE="$WORK/current.json"
python3 - "$ALL_TSV" "$CURRENT_STATE" <<'PYEOF'
import sys, json
state = {}
with open(sys.argv[1]) as f:
    for line in f:
        line = line.rstrip('\n')
        if not line:
            continue
        parts = line.split('\t', 1)
        url = parts[0]
        lastmod = parts[1] if len(parts) > 1 else ''
        state[url] = lastmod
with open(sys.argv[2], 'w') as f:
    json.dump(state, f, sort_keys=True, indent=2)
PYEOF

# ── Step 5: load previous state and compute diff ────────────────────────────
FIRST_RUN="false"
if [ ! -f "$STATE_FILE" ]; then
  echo "  🆕 No previous state — first run"
  FIRST_RUN="true"
  echo '{}' > "$STATE_FILE"
fi

DIFF_FILE="$WORK/diff.txt"
python3 - "$STATE_FILE" "$CURRENT_STATE" "$DIFF_FILE" <<'PYEOF'
import sys, json

with open(sys.argv[1]) as f:
    prev = json.load(f)
with open(sys.argv[2]) as f:
    curr = json.load(f)

changed = []
for url, lastmod in curr.items():
    prev_lm = prev.get(url)
    if prev_lm is None:
        changed.append(url)        # new URL
    elif prev_lm != lastmod:
        changed.append(url)        # lastmod changed

with open(sys.argv[3], 'w') as f:
    for u in changed:
        f.write(u + '\n')
PYEOF

CHANGED_COUNT=$(wc -l < "$DIFF_FILE" | tr -d ' ')
echo "  🔍 Changed/new URLs: $CHANGED_COUNT"

# ── Step 6: apply caps (first-run vs steady-state) ──────────────────────────
EFFECTIVE_LIMIT="$MAX_URLS"
if [ "$FIRST_RUN" = "true" ] && [ "$CHANGED_COUNT" -gt "$FIRST_RUN_LIMIT" ]; then
  echo "  🛑 First run + $CHANGED_COUNT URLs > FIRST_RUN_LIMIT=$FIRST_RUN_LIMIT — capping"
  EFFECTIVE_LIMIT="$FIRST_RUN_LIMIT"
fi

if [ "$CHANGED_COUNT" -gt "$EFFECTIVE_LIMIT" ]; then
  head -n "$EFFECTIVE_LIMIT" "$DIFF_FILE" > "$OUT_URL_LIST_FILE"
  echo "  ✂️  Capped to $EFFECTIVE_LIMIT URLs"
else
  cp "$DIFF_FILE" "$OUT_URL_LIST_FILE"
fi

EMITTED_COUNT=$(wc -l < "$OUT_URL_LIST_FILE" | tr -d ' ')

# ── Step 7: persist new state (only if we successfully got URLs) ────────────
cp "$CURRENT_STATE" "$STATE_FILE"
echo "  💾 State file updated: $STATE_FILE"

# ── Step 8: GitHub Actions outputs ──────────────────────────────────────────
{
  echo "changed-count=$CHANGED_COUNT"
  echo "emitted-count=$EMITTED_COUNT"
  echo "total-count=$TOTAL_COUNT"
  echo "first-run=$FIRST_RUN"
} >> "${GITHUB_OUTPUT:-/dev/null}"

echo ""
echo "📤 Emitting $EMITTED_COUNT URL(s) to: $OUT_URL_LIST_FILE"
exit 0
