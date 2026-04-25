# 📋 SEO Checklist — Static Site Setup

5-minute manual setup for a new static site. Run through this once per project, then the GitHub Action handles ongoing automation.

---

## 1. On-page SEO (per page)

Each HTML page must have:

- [ ] **Unique `<title>`** under 60 characters (Google truncates ~580px)
- [ ] **Unique `<meta name="description">`** 140–160 characters
- [ ] **`<meta name="keywords">`** (3–8 keywords, lowercase, comma-separated)
- [ ] **Canonical URL** — `<link rel="canonical" href="https://www.example.com/page/">`
- [ ] **`<html lang="cs">`** (or appropriate locale)
- [ ] **Open Graph tags**: `og:title`, `og:description`, `og:image` (1200×630), `og:url`, `og:type`
- [ ] **Twitter Card**: `twitter:card="summary_large_image"`
- [ ] **One H1 per page** matching primary keyword intent
- [ ] **Schema.org JSON-LD** where applicable (`Product`, `FAQPage`, `BreadcrumbList`, `Organization`)

### Reference snippet

```html
<title>Page Title — Brand</title>
<meta name="description" content="Short, compelling 140–160 char description with primary keyword.">
<meta name="keywords" content="keyword1, keyword2, keyword3">
<link rel="canonical" href="https://www.example.com/page/">

<meta property="og:type" content="website">
<meta property="og:url" content="https://www.example.com/page/">
<meta property="og:title" content="Page Title — Brand">
<meta property="og:description" content="Same as meta description or shorter.">
<meta property="og:image" content="https://www.example.com/og-image.jpg">

<meta name="twitter:card" content="summary_large_image">
```

---

## 2. Site-wide files

- [ ] **`/robots.txt`** — allow all + Crawl-delay 1 + explicit AI bot opt-in (GPTBot, ClaudeBot, anthropic-ai, Google-Extended)
- [ ] **`/sitemap.xml`** — all public URLs with `<lastmod>`, `<changefreq>`, `<priority>`
- [ ] Sitemap referenced in `robots.txt`: `Sitemap: https://www.example.com/sitemap.xml`
- [ ] **`/{indexnow-key}.txt`** — IndexNow verification file (32 hex chars, plaintext)
- [ ] **`/favicon.ico`** + `apple-touch-icon.png`

---

## 3. Performance (Core Web Vitals)

- [ ] All images **under 150 KB** (preferably 50–100 KB) — use WebP for photos
- [ ] **Width/height attributes** on `<img>` tags (prevents CLS)
- [ ] **Lazy loading** for below-the-fold images: `loading="lazy"`
- [ ] **Eager loading** for hero/LCP image: `loading="eager" fetchpriority="high"`
- [ ] CSS inlined or in single shared file
- [ ] No blocking JS in `<head>`
- [ ] Test with PageSpeed Insights — aim for **Performance > 90** on mobile

---

## 4. Accessibility (a11y)

- [ ] All `<img>` tags have descriptive `alt` (or `alt=""` for decorative)
- [ ] Skip link: `<a class="skip-link" href="#main">Přeskočit na obsah</a>`
- [ ] Logical heading order (H1 → H2 → H3, no skips)
- [ ] Focus visible on all interactive elements
- [ ] Color contrast ≥ 4.5:1 for body text
- [ ] Forms have `<label>` for every input
- [ ] `<html lang="...">` set correctly

---

## 5. Internal linking

- [ ] Every page reachable in **≤3 clicks** from homepage
- [ ] Footer with links to: privacy, terms, contact, sitemap
- [ ] Breadcrumbs on deep pages (with `BreadcrumbList` schema)
- [ ] Related-content links between thematic pages

---

## 6. External setup (one-time)

### Google Search Console
1. Add property at https://search.google.com/search-console
2. Choose **URL prefix** (easier) or **Domain** (better, requires DNS TXT)
3. For URL prefix: upload Google's `googleXXXXXX.html` to repo root
4. Verify
5. Submit `sitemap.xml` in Sitemaps section

### Bing Webmaster Tools
1. https://www.bing.com/webmasters
2. **Import from Google Search Console** (one-click) — easiest path
3. Submit sitemap

### IndexNow setup
1. `openssl rand -hex 16` → save as `INDEXNOW_KEY` GitHub Secret
2. Create `/{key}.txt` in repo root with key as plaintext content
3. Add `seo-pipeline` step to deploy workflow (see README)

### Facebook App (for OG cache refresh)
1. https://developers.facebook.com/apps → Create Business app
2. App Settings → Basic → copy App ID + App Secret
3. Compose token: `{AppID}|{AppSecret}`
4. Save as `FB_APP_ACCESS_TOKEN` GitHub Secret

---

## 7. Wire up the GitHub Action

Add to `.github/workflows/deploy.yml` after your deploy step:

```yaml
- name: SEO Pipeline
  uses: LiorD78/seo-pipeline@v1
  with:
    host: www.example.com
    indexnow-key: ${{ secrets.INDEXNOW_KEY }}
    fb-access-token: ${{ secrets.FB_APP_ACCESS_TOKEN }}
    url-list: |
      https://www.example.com/
      https://www.example.com/about/
```

Push a commit. Verify in GitHub Actions logs:
- `✅ IndexNow accepted (HTTP 200)` or `(HTTP 202)`
- `📘 FB OG refresh: N success, 0 failed`

---

## 8. Maintenance

- **When adding a new page:** add URL to the `url-list` in deploy workflow + add `<url>` entry in `sitemap.xml`
- **When changing OG image:** push the change — FB cache auto-refreshes on next deploy
- **Monthly:** check GSC Coverage report for indexing errors
- **Quarterly:** rotate FB App Secret if leaked (App Settings → Basic → Reset)

---

*Last updated: 2026-04-25*
