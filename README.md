# 🔍 SEO Pipeline — Reusable GitHub Action

Composite GitHub Action for SEO automation. Pings:

- **IndexNow** (Bing, Yandex, Seznam, Naver) — instant index notification
- **Facebook Graph API** — refreshes Open Graph cache (`og:title`, `og:image`, `og:description`)
- **Google sitemap ping** *(optional, legacy)*

Two modes:

- 🚀 **`deploy-driven`** *(default)* — provide an explicit `url-list`. Use after a deploy step on static sites (Netlify, Vercel, GitHub Pages, FTP).
- 🗺️ **`sitemap-driven`** — fetches `sitemap.xml`, diffs against stored state, and pings only **new or changed** URLs. Perfect for hosted e-commerce platforms (BSSHOP, Shoptet, PrestaShop) where you don't control deploys but the platform publishes a sitemap.

---

## Quick start — deploy-driven (static sites)

In your repo's `.github/workflows/deploy.yml`, add the SEO step **after** your deploy step:

```yaml
- name: SEO Pipeline (IndexNow + FB Graph)
  uses: LiorD78/seo-pipeline@v2
  with:
    host: www.example.com
    indexnow-key: ${{ secrets.INDEXNOW_KEY }}
    fb-access-token: ${{ secrets.FB_APP_ACCESS_TOKEN }}
    url-list: |
      https://www.example.com/
      https://www.example.com/about/
      https://www.example.com/contact/
      https://www.example.com/blog/
```

That's it. Both steps are **best-effort** by default — pipeline does not fail if Bing/FB rejects.

---

## Quick start — sitemap-driven (hosted platforms / large sites)

Create a tiny "monitor" repo with just one workflow. The action will fetch the sitemap on each cron tick, diff it against a state file committed back to the repo, and ping only what changed:

```yaml
# .github/workflows/sitemap-watch.yml
name: Sitemap watch
on:
  schedule:
    - cron: '0 */4 * * *'   # every 4 hours
  workflow_dispatch:

permissions:
  contents: write    # required for commit-state

jobs:
  watch:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: LiorD78/seo-pipeline@v2
        with:
          mode: sitemap-driven
          host: www.example.com
          sitemap-url: https://www.example.com/sitemap.xml
          state-file: .seo-state/example.json
          first-run-limit: 50      # don't ping the entire site on first run
          indexnow-key: ${{ secrets.INDEXNOW_KEY }}
          fb-access-token: ${{ secrets.FB_APP_ACCESS_TOKEN }}
```

The action handles `<sitemapindex>` → multiple sub-sitemaps automatically. Diff is computed by comparing each URL's `<lastmod>` against the previous run.

---

## Inputs

### Common

| Input | Required | Default | Description |
|---|---|---|---|
| `host` | ✅ | — | Domain without protocol, e.g. `www.example.com` |
| `mode` | ❌ | `deploy-driven` | `deploy-driven` or `sitemap-driven` |
| `indexnow-key` | ❌ | `''` | IndexNow API key (32 hex chars). Step skipped if empty. |
| `indexnow-key-location` | ❌ | `https://{host}/{key}.txt` | Public URL of the verification key file |
| `fb-access-token` | ❌ | `''` | Facebook App Access Token in format `{AppID}\|{AppSecret}` |
| `fail-on-error` | ❌ | `false` | If `true`, fails the workflow on any sub-step error |

### Deploy-driven mode

| Input | Required | Default | Description |
|---|---|---|---|
| `url-list` | ✅ | — | Newline-separated full URLs (no quotes, no commas) |

### Sitemap-driven mode

| Input | Required | Default | Description |
|---|---|---|---|
| `sitemap-url` | ✅ | — | Full sitemap URL (`<sitemapindex>` is auto-expanded) |
| `state-file` | ❌ | `.seo-state/sitemap-state.json` | Path to JSON state file (committed back to repo) |
| `max-urls` | ❌ | `10000` | Cap URLs per run |
| `first-run-limit` | ❌ | `100` | On first run only (no state), cap to this many URLs |
| `commit-state` | ❌ | `true` | Auto-commit updated state-file back to repo |

### Outputs (sitemap-driven mode)

| Output | Description |
|---|---|
| `changed-count` | URLs detected as new or changed |
| `emitted-count` | URLs actually pinged (after caps) |
| `total-count` | Total URLs in sitemap |

---

## Setup checklist for a new project

### 1. IndexNow key
Generate a 32-character hex key:
```bash
openssl rand -hex 16
```
Then:
1. Add `{key}.txt` to your repo root, containing **just the key** as plaintext
2. Verify it loads at `https://{host}/{key}.txt` after deploy
3. Save the key as a GitHub Secret named `INDEXNOW_KEY`

### 2. Facebook App
1. Create a Meta App at https://developers.facebook.com/apps (type: "Business")
2. App Settings → Basic → copy **App ID** and **App Secret**
3. Compose token as `{AppID}|{AppSecret}` (literally, with the pipe)
4. Save as GitHub Secret `FB_APP_ACCESS_TOKEN`

This token is **long-lived** and does not expire. Rotate the App Secret to invalidate it.

### 3. (Optional) Google Search Console
Manual one-time setup — see [SEO-CHECKLIST.md](./SEO-CHECKLIST.md).

---

## How the inputs work

`url-list` is a YAML literal block — each non-empty line becomes one URL:

```yaml
url-list: |
  https://example.com/
  https://example.com/page-1/
  https://example.com/page-2/
```

The action handles JSON encoding for IndexNow internally via `jq`. You don't need to escape anything.

---

## Versioning

- `@v2` — sliding tag for v2.x (sitemap-driven mode + backward-compatible deploy-driven)
- `@v1` — sliding tag for v1.x (deploy-driven only, frozen)
- `@v2.0.0` — pin to a specific release for full reproducibility

---

## License

MIT — Libor Dospěl / TDT s.r.o.
