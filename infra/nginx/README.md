# Nginx / TLS

Put the public reverse proxy here (Caddy/Nginx/Traefik) when deploying with domains.
The app-specific Nginx configs live next to each app:

- `apps/web/nginx.conf` — Next.js static export
- `apps/mobile/nginx.conf` — Flutter mobile/full web
- `apps/admin/nginx.conf` — admin SPA

Recommended host mapping:

```text
www.example.com     -> 127.0.0.1:8083   (Next.js)
app.example.com     -> 127.0.0.1:8081   (Flutter mobile web, optional)
admin.example.com   -> 127.0.0.1:3000
api.example.com     -> 127.0.0.1:8080
```

Production TLS: terminate at the edge (Caddy/Cloudflare/Nginx) and forward
`X-Forwarded-For` / `X-Forwarded-Proto`; API has `ReverseProxy__TrustForwarded=true`.
