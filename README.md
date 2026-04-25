# 🔍 SEO Pipeline — Reusable GitHub Action

Composite GitHub Action for static-site SEO automation. Runs after a successful deploy and pings:

- **IndexNow** (Bing, Yandex, Seznam, Naver) — instant index notification
- **Facebook Graph API** — refreshes Open Graph cache (`og:title`, `og:image`, `og:description`)
- **Google sitemap ping** *(optional, legacy)*

Designed for static HTML sites deployed via FTP, Netlify, Vercel, GitHub Pages, etc.

---

## Quick start

In your repo's `.github/workflows/deploy.yml`, add the SEO step **after** your deploy step:

```yaml
- name: SEO Pipeline (IndexNow + FB Graph)
  uses: LiorD78/seo-pipeline@v1
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

## Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `host` | ✅ | — | Domain without protocol, e.g. `www.example.com` |
| `url-list` | ✅ | — | Newline-separated full URLs (no quotes, no commas) |
| `indexnow-key` | ❌ | `''` | IndexNow API key (32 hex chars). Step skipped if empty. |
| `indexnow-key-location` | ❌ | `https://{host}/{key}.txt` | Public URL of the verification key file |
| `fb-access-token` | ❌ | `''` | Facebook App Access Token in format `{AppID}|{AppSecret}` |
| `sitemap-url` | ❌ | `''` | Full sitemap URL (e.g. `https://www.example.com/sitemap.xml`) |
| `ping-google-sitemap` | ❌ | `false` | Whether to ping Google legacy sitemap endpoint |
| `fail-on-error` | ❌ | `false` | If `true`, fails the workflow on any sub-step error |

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

Pin to `@v1` for the major version (auto-updated within v1.x). Pin to a SHA for reproducibility.

---

## License

MIT — Libor Dospěl / TDT s.r.o.
