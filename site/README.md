# omastorm.com holding page

Static, no build step. `index.html` plus two PNG crops of the radar viewport
from `docs/media/{dark,light}-glyphs.png` (offset 21,123; size 1158×540). The
page follows the visitor's color scheme and swaps the image to match.

Regenerate the crops after a new capture:

```sh
for t in dark light; do
  magick docs/media/$t-glyphs.png -crop 1158x540+21+123 +repage -strip site/radar-$t.png
done
```

Hosted on Cloudflare Pages, project `omastorm`, deployed by direct upload
so the holding page stays independent of the git repo. First deployed
2026-09-05. The zone
omastorm.com has proxied CNAME records for the root and `www` pointing at
`omastorm.pages.dev`. Redeploy after any change:

```sh
npx wrangler pages deploy site --project-name omastorm --branch main
```

Wrangler is logged in with an OAuth token holding Pages write and zone read.
DNS changes need the Cloudflare MCP server or the dashboard.

The page deliberately links to no repository and no video. It plants the name
without spending the demo.
