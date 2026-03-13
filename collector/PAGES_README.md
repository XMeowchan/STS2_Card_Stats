# Collector Pages Publishing

Use this inside `XMeowchan/Fetch-STS2_Card-Stats` to publish mod-ready data for GitHub Pages.

## Build locally

```bash
npm run xhh:pages
```

This generates:

- `public/cards.json`
- `public/index.html`
- `public/.nojekyll`

## GitHub Actions

The workflow template is in `.github/workflows/deploy-pages.yml`.

When GitHub Pages is enabled with `GitHub Actions` as the source, the published URL will be:

```text
https://xmeowchan.github.io/Fetch-STS2_Card-Stats/cards.json
```
