# Infrastructure

Deployment assets cho Sharee.

```text
infra/
├── compose/
│   ├── docker-compose.yml          # demo/local full stack
│   ├── docker-compose.prod.yml     # production full stack
│   └── docker-compose.web.yml      # Next.js web riêng
└── nginx/                          # ghi chú reverse proxy/TLS
```

## Thành phần runtime

| Service | Image / build | Port |
|---|---|---|
| API | `backend/Dockerfile` | 8080 |
| Mobile web (Flutter) | `apps/mobile/Dockerfile` | 8081 |
| Full web (Flutter desktop) | `apps/mobile/FullWeb.Dockerfile` | 8082 |
| **Next.js web** | `apps/web/Static.Dockerfile` | 8083 |
| Admin | `apps/admin/Dockerfile` | 3000 |
| PostgreSQL/PostGIS | `postgis/postgis:16-3.4` | nội bộ |
| Redis | `redis:7-alpine` | nội bộ |

## Demo stack

```bash
docker compose -f infra/compose/docker-compose.yml up -d --build
```

## Next.js web

Build tĩnh:

```bash
cd apps/web
NEXT_PUBLIC_API_URL=https://api.example.com npm run build
# output: apps/web/out
```

Docker:

```bash
docker build -f apps/web/Static.Dockerfile -t sharee-web .
docker run -p 8083:80 sharee-web
```

Hoặc:

```bash
docker compose -f infra/compose/docker-compose.web.yml up -d --build
```

## Production

```bash
cp .env.example .env
docker compose -f infra/compose/docker-compose.prod.yml --env-file .env up -d --build
```

Cần cấu hình reverse proxy TLS cho các domain:
- `www.example.com` → Next.js `:8083`
- `app.example.com` → Flutter mobile web `:8081` (tuỳ chọn)
- `admin.example.com` → admin `:3000`
- `api.example.com` → API `:8080`

Không mở PostgreSQL/Redis ra Internet.
