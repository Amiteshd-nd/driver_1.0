# `verify` — public card verify page

Server-rendered HTML (with Open Graph / Twitter meta so WhatsApp and Instagram show a card preview) for
`https://<project>.supabase.co/functions/v1/verify/<animal-slug>/<serial>`.

Routes handled by `index.ts` (plain `Deno.serve`, no dependencies):

| Route | Returns |
|---|---|
| `GET /verify/<slug>/<serial>` | HTML page: the card, "Earned by … on …", "#0042 of 118 issued", the Real ✓ seal, store buttons. 404 + "No such card" when the ledger has no match. |
| `GET /verify/<slug>/<serial>/card.svg` | 1200 × 630 SVG used as `og:image` (procedural placeholder art, no external fonts needed). |
| `GET /verify?q=Tiger%20%230427` | Same page for a free-form serial (accepts `"tiger 427"`, `"TGR-0427"`). |
| `GET /verify` | Search form. |

Every response carries `Cache-Control: public, max-age=300` (errors are `no-store`). Only whitelisted fields from `lookup_serial` are rendered and every string is HTML-escaped; location, route and health fields never reach the page.

## Deploy

```sh
supabase functions deploy verify --no-verify-jwt
```

`--no-verify-jwt` is required: the page is for people without the app, so requests carry no user JWT.

## Environment

Two variables, both already present in every Supabase project's function runtime (so nothing to set when deployed there):

| Var | Purpose |
|---|---|
| `SUPABASE_URL` | Project URL, e.g. `https://abcd.supabase.co`. The function POSTs to `${SUPABASE_URL}/rest/v1/rpc/lookup_serial`. |
| `SUPABASE_ANON_KEY` | Anon key, sent as `apikey` and `Authorization: Bearer`. `lookup_serial` is the only RPC granted to `anon`. |

Optional: `PUBLIC_BASE_URL` (e.g. `https://pugmark.run`) overrides the origin used for absolute `og:image` / `og:url` URLs when the function sits behind a custom domain or proxy. Set with `supabase secrets set PUBLIC_BASE_URL=https://pugmark.run`.

## Local

```sh
supabase start
supabase functions serve verify --no-verify-jwt --env-file supabase/.env.local
open "http://localhost:54321/functions/v1/verify?q=Tiger%20%230427"
```

## Pointing `pugmark.run/v/...` here

`cfg('app').verify_base_url` produces `https://pugmark.run/v/<slug>/<serial>`. Rewrite `/v/*` at the CDN/host to `https://<project>.supabase.co/functions/v1/verify/*` and set `PUBLIC_BASE_URL=https://pugmark.run`. The static fallback at `web/marketing/verify.html` reads the same `#/<slug>/<serial>` shape if the rewrite is unavailable.
