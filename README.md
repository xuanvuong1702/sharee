# Sharee â€” á»©ng dá»¥ng Ä‘i chung xe (BlaBlaCar-style) + cháº¿ Ä‘á»™ Daily

Äá»“ Ã¡n há»c táº­p Ä‘Æ°á»£c triá»ƒn khai Ä‘áº§y Ä‘á»§: **backend ASP.NET Core 10 + PostgreSQL/PostGIS**, **Flutter mobile app**,
**React admin**, **Docker Compose**, migration/seed tá»± Ä‘á»™ng, unit test vÃ  smoke test end-to-end.

> Cáº¥u hÃ¬nh trong repo lÃ  **demo**, báº­t OTP dev, seed dá»¯ liá»‡u máº«u vÃ  thanh toÃ¡n mock.
> TrÆ°á»›c khi cháº¡y cho khÃ¡ch tháº­t, Ä‘á»c [PRODUCTION.md](PRODUCTION.md) vÃ  dÃ¹ng `infra/compose/docker-compose.prod.yml`.

## Giao diá»‡n

- Design system riÃªng: palette navy/electric blue, thang chá»¯, radius 20â€“28, shadow má»m, tráº¡ng thÃ¡i mÃ u thá»‘ng nháº¥t.
- Mobile-first: app bar gá»n, bottom nav ná»•i 5 tab, sticky CTA, bottom sheet, safe-area vÃ  vÃ¹ng cháº¡m â‰¥ 44px.
- Tráº£i nghiá»‡m: skeleton loading, pull-to-refresh, empty state cÃ³ hÃ nh Ä‘á»™ng, transition mÆ°á»£t, haptic feedback.
- Báº£n web Ä‘Æ°á»£c Ä‘Ã³ng khung 480px nhÆ° má»™t chiáº¿c Ä‘iá»‡n thoáº¡i Ä‘á»ƒ kiá»ƒm chá»©ng UI trÃªn desktop.

## Cháº¡y trong 1 lá»‡nh

```bash
docker compose up -d --build
```

| Dá»‹ch vá»¥ | URL | Ghi chÃº |
|---|---|---|
| API + Swagger | http://localhost:8080/swagger | REST + SignalR `/hubs/chat`, `/hubs/notifications` |
| Admin web | http://localhost:3000 | Ä‘Äƒng nháº­p báº±ng OTP admin |
| Mobile web (Flutter) | http://localhost:8081 | báº£n build web cá»§a app Flutter |
| PostgreSQL/PostGIS | localhost:5432 | user/pass/db: `sharee` |
| Redis | localhost:6379 | SignalR backplane + cache |

Health checks: `GET /health/live`, `GET /health/ready` (DB readiness), `GET /health` (tÆ°Æ¡ng thÃ­ch cÅ©).

> Náº¿u build mobile web láº§n Ä‘áº§u: `cd apps/mobile && flutter build web --dart-define=API_BASE_URL=http://localhost:8080`
> trÆ°á»›c khi `docker compose up --build` (Dockerfile copy `build/web`).

## TÃ i khoáº£n demo

OTP Ä‘Æ°á»£c tráº£ vá» trong response (`devCode`) khi `Auth:ExposeOtp=true` (máº·c Ä‘á»‹nh trong demo).

| Vai trÃ² | Sá»‘ Ä‘iá»‡n thoáº¡i |
|---|---|
| Admin | `+84900000001` |
| HÃ nh khÃ¡ch | `+84912345678` (Minh) |
| TÃ i xáº¿ | `+84912000001` (Trung KiÃªn) |
| TÃ i xáº¿ | `+84912000002` (Minh Háº±ng) |

Seed sáºµn 4 chuyáº¿n HÃ  Ná»™i â†’ Háº£i PhÃ²ng/Ná»™i BÃ i (ngÃ y mai, giá» Viá»‡t Nam), 1 tuyáº¿n Daily á»Ÿ TP.HCM
(Báº¿n ThÃ nh â€“ Suá»‘i TiÃªn, 6 tráº¡m), bÃ¡o cÃ¡o vÃ  há»“ sÆ¡ chá» duyá»‡t.

## Kiáº¿n trÃºc

```text
Flutter app â”€â”€â”
React admin â”€â”€â”¼â”€â”€ HTTP/JSON â”€â”€â–¶ ASP.NET Core minimal API
              â”‚                  â”œâ”€ Auth (OTP + JWT)
              â”‚                  â”œâ”€ Trips / Search (PostGIS)
              â”‚                  â”œâ”€ Bookings (atomic seat hold)
              â”‚                  â”œâ”€ Payments + double-entry ledger
              â”‚                  â”œâ”€ Chat (REST + SignalR)
              â”‚                  â”œâ”€ Reviews / Reports / Admin
              â”‚                  â””â”€ Daily (lines, e-tickets, validations)
              â”‚                        â”‚
              â”‚                  PostgreSQL + PostGIS
              â”‚                  Redis (optional)
              â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ SignalR /hubs/chat
```

### Quyáº¿t Ä‘á»‹nh ká»¹ thuáº­t

- **PostGIS** cho tÃ¬m chuyáº¿n theo stop: `ST_DWithin` trÃªn `trip_stops.location`, ghÃ©p cáº·p stop
  `pickup.seq < dropoff.seq`; giÃ¡ cháº·ng = `price_from_origin(drop) - price_from_origin(pick)`.
- **Giá»¯ gháº¿ nguyÃªn tá»­**:
  `UPDATE trips SET seats_available = seats_available - @n WHERE id=@id AND seats_available >= @n`
  trong cÃ¹ng transaction vá»›i insert booking; idempotency key chá»‘ng Ä‘áº·t trÃ¹ng.
- **Sá»• cÃ¡i kÃ©p**: má»—i giao dá»‹ch cÃ³ `ledger_transactions` + cÃ¡c dÃ²ng D/C cÃ¢n báº±ng; hoÃ n tiá»n ghi bÃºt toÃ¡n Ä‘áº£o.
- **Refresh token** xoay vÃ²ng: access token 60 phÃºt (production 15 phÃºt), refresh 30 ngÃ y, revoke khi logout.
- **Outbox worker** Ä‘Ã¡nh dáº¥u event Ä‘Ã£ xá»­ lÃ½; notifications ghi trong cÃ¹ng transaction.
- **Daily**: tuyáº¿n + tráº¡m + QR/e-ticket 30 phÃºt; tÃ i xáº¿ nháº­n vÃ©, xÃ¡c nháº­n báº±ng mÃ£ 4 sá»‘; trá»£ giÃ¡ theo km.
- **Chuyáº¿n Ä‘á»‹nh ká»³**: lá»‹ch cháº¡y theo tuáº§n, tá»± materialize chuyáº¿n cho 14 ngÃ y tá»›i, worker gia háº¡n má»—i 6 giá».
- **Thu nháº­p tÃ i xáº¿**: tá»•ng há»£p booking hoÃ n thÃ nh (VND) vÃ  Daily (EUR), mÃ n hÃ¬nh vÃ­ trong app.
- **Theo dÃµi trá»±c tiáº¿p**: báº£n Ä‘á»“ OpenStreetMap, vá»‹ trÃ­ tÃ i xáº¿ + khÃ¡ch, route, ETA, tráº¡ng thÃ¡i chuyáº¿n;
  driver chia sáº» GPS (hoáº·c mÃ´ phá»ng khi trÃ¬nh duyá»‡t cháº·n quyá»n), client cáº­p nháº­t má»—i 3 giÃ¢y.
- **Chat realtime**: SignalR `/hubs/chat`, lá»‹ch sá»­ tin nháº¯n lÆ°u PostgreSQL (táº£i láº¡i váº«n cÃ²n), thread list tá»± cáº­p nháº­t.
- **Notification realtime**: SignalR `/hubs/notifications` + outbox worker, badge sá»‘ chÆ°a Ä‘á»c trÃªn trang chá»§.
- **Audit log** cho duyá»‡t há»“ sÆ¡, xá»­ lÃ½ bÃ¡o cÃ¡o vÃ  hoÃ n tiá»n thá»§ cÃ´ng.

## API chÃ­nh

```
POST /api/auth/otp/request            {phone} -> {expiresIn, devCode}
POST /api/auth/otp/verify             {phone, code} -> {accessToken, refreshToken, user}
POST /api/auth/refresh                {refreshToken} -> token má»›i
POST /api/auth/logout                 revoke refresh token
GET  /api/me
GET  /api/me/earnings                 thu nháº­p tÃ i xáº¿ (chuyáº¿n + Daily)
GET  /api/trips/search?fromLat&fromLng&toLat&toLng&date&seats
GET  /api/trips/{id}
POST /api/trips                       (driver)
POST /api/trips/recurring             lá»‹ch cháº¡y theo tuáº§n
GET  /api/trips/recurring
DELETE /api/trips/recurring/{id}      táº¡m dá»«ng
GET  /api/trips/{id}/tracking         vá»‹ trÃ­ tÃ i xáº¿/khÃ¡ch + ETA + route
POST /api/trips/{id}/location         cáº­p nháº­t GPS (driver/passenger)
POST /api/trips/{id}/tracking/status  en_route | arrived | in_progress | completed
POST /api/trips/{id}/bookings         (Idempotency-Key)
POST /api/bookings/{id}/pay
GET  /api/bookings/mine
POST /api/bookings/{id}/accept|reject|cancel|complete
POST /api/bookings/{id}/reviews
GET  /api/conversations
GET  /api/conversations/{id}/messages
POST /api/conversations/{id}/messages
GET  /api/daily/lines
GET  /api/daily/lines/{id}
POST /api/daily/e-tickets
POST /api/daily/e-tickets/{id}/assign|validate
GET  /api/daily/my-tickets
GET  /api/daily/driver/queue
GET  /api/daily/partner/summary        (admin)
GET  /api/notifications
POST /api/notifications/read-all
GET  /api/admin/dashboard
GET  /api/admin/verifications
POST /api/admin/verifications/{id}/approve|reject
GET  /api/admin/reports
PATCH /api/admin/reports/{id}?status=resolved
GET  /api/admin/refunds
POST /api/admin/refunds/{bookingId}
GET  /api/admin/audit
```

SignalR hubs (JWT qua `?access_token=`):

```
/hubs/chat             JoinConversation, SendMessage; events: message, thread
/hubs/notifications    event: notification (realtime badge/list)
```

Swagger Ä‘áº§y Ä‘á»§: http://localhost:8080/swagger

## Cáº¥u trÃºc repo

```
backend/
  src/Sharee.Api/          API, endpoints, services, migrations (embedded SQL)
  tests/Sharee.Tests/      unit tests
apps/
  mobile/                  Flutter Android/iOS + mobile web
  web/                     Next.js consumer web (static export)
  admin/                   React + Vite admin
packages/
  ui/                      React UI primitives
  api-client/              typed API client
  design-tokens/           colors, spacing, typography
infra/
  compose/                 docker compose stacks
  nginx/                   reverse proxy/TLS notes
infra/scripts/smoke.ps1          smoke test end-to-end
```

## PhÃ¡t triá»ƒn

```bash
# Backend (cáº§n Postgres/Redis tá»« compose)
dotnet run --project backend/src/Sharee.Api

# Flutter
cd apps/mobile
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080

# Flutter Android (emulator dÃ¹ng 10.0.2.2)
flutter build apk --dart-define=API_BASE_URL=http://10.0.2.2:8080
# APK: apps/mobile/build/app/outputs/flutter-apk/app-debug.apk

# Admin
cd apps/admin
npm install
npm run dev

# Next.js web
cd apps/web
npm install
npm run dev -- --port 3002
# build static: npm run build
```

## Kiá»ƒm thá»­

```bash
dotnet test backend/tests/Sharee.Tests
cd apps/mobile && flutter test
powershell -File infra/scripts/smoke.ps1
powershell -File infra/scripts/oversell.ps1
```

- `smoke.ps1`: Ä‘Äƒng nháº­p OTP â†’ tÃ¬m chuyáº¿n â†’ Ä‘áº·t 1 gháº¿ â†’ thanh toÃ¡n â†’ chat â†’ táº¡o vÃ© Daily â†’ tÃ i xáº¿ xÃ¡c nháº­n.
- `oversell.ps1`: báº¯n 6 request Ä‘áº·t gháº¿ Ä‘á»“ng thá»i, assert khÃ´ng bÃ¡n quÃ¡ sá»‘ gháº¿ (201 = 1, 409 = 5).
- `node tools/uicheck/realtime-check.mjs`: kiá»ƒm tra chat realtime, lá»‹ch sá»­ lÆ°u DB vÃ  notification realtime.

## Thanh toÃ¡n PayOS

- Mobile gá»i `POST /api/bookings/{id}/payos`, nháº­n `checkoutUrl` + QR, má»Ÿ PayOS vÃ  poll tráº¡ng thÃ¡i booking.
- Webhook `POST /api/payments/payos/webhook` xÃ¡c minh HMAC-SHA256, chá»‘t booking + ledger idempotent.
- Báº­t production:

```env
Payments__Provider=payos
PayOS__Enabled=true
PayOS__ClientId=...
PayOS__ApiKey=...
PayOS__ChecksumKey=...
PayOS__ReturnUrl=https://app.example.com/payment/return
PayOS__CancelUrl=https://app.example.com/payment/cancel
```

- Demo dÃ¹ng mock; production tá»± cháº·n mock.
- Kiá»ƒm thá»­ gateway giáº£: `node tools/uicheck/payos-check.mjs`.

## Tip / donate cho tÃ i xáº¿

- TÃ i xáº¿ cáº¥u hÃ¬nh **BIN ngÃ¢n hÃ ng + sá»‘ tÃ i khoáº£n + tÃªn chá»§ tÃ i khoáº£n** trong Há»“ sÆ¡ â†’ **Nháº­n tip**.
- QR Ä‘Æ°á»£c sinh trá»±c tiáº¿p theo chuáº©n **VietQR/NAPAS 247**, khÃ´ng phá»¥ thuá»™c dá»‹ch vá»¥ áº£nh QR bÃªn thá»© ba.
- HÃ nh khÃ¡ch cÃ³ thá»ƒ tip sau khi chuyáº¿n **hoÃ n thÃ nh**:
  - **Chuyá»ƒn khoáº£n/QR**: tÃ i xáº¿ nháº­n thÃ´ng bÃ¡o, khÃ¡ch bÃ¡o Ä‘Ã£ chuyá»ƒn, tÃ i xáº¿ xÃ¡c nháº­n;
  - **Tiá»n máº·t**: ghi nháº­n ngay vÃ  thÃ´ng bÃ¡o cho tÃ i xáº¿.
- ThÃ´ng bÃ¡o realtime qua SignalR + push (náº¿u cáº¥u hÃ¬nh FCM/APNs).
- Thu nháº­p tip hiá»ƒn thá»‹ trong **Thu nháº­p** vÃ  **Tip Ä‘Ã£ nháº­n**.

API chÃ­nh:
```text
GET  /api/me/tip-account
PUT  /api/me/tip-account
GET  /api/bookings/{id}/tip-info
POST /api/bookings/{id}/tips
POST /api/tips/{id}/sent
POST /api/tips/{id}/confirm
POST /api/tips/{id}/cancel
GET  /api/me/tips
```

Tip chuyá»ƒn khoáº£n/tiá»n máº·t Ä‘i **trá»±c tiáº¿p** giá»¯a khÃ¡ch vÃ  tÃ i xáº¿, Sharee chá»‰ ghi nháº­n vÃ  thÃ´ng bÃ¡o.
Muá»‘n thu tiá»n qua ná»n táº£ng (PayOS) thÃ¬ cáº§n bá»• sung luá»“ng thanh toÃ¡n/Ä‘á»‘i soÃ¡t riÃªng.

## Push FCM / APNs

- Backend: FCM HTTP v1 + APNs HTTP/2, device token API, outbox gá»­i push sau notification.
- Mobile: `firebase_core` + `firebase_messaging`, token tá»± Ä‘Äƒng kÃ½ sau Ä‘Äƒng nháº­p.
- Cáº¥u hÃ¬nh mobile:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=...
```

- Backend: `Push__Fcm__ProjectId`, service account JSON (hoáº·c file trong container), APNs key náº¿u dÃ¹ng trá»±c tiáº¿p.
- Chi tiáº¿t: [PRODUCTION.md](PRODUCTION.md).

## Bốn bản triển khai

| Bản | Build | Docker / port |
|---|---|---|
| **Web người dùng (Next.js)** | `cd apps/web && npm run build` | `apps/web/Static.Dockerfile` · `8083` |
| **Web mobile (Flutter)** | `--dart-define=WEB_MODE=mobile` | `apps/mobile/Dockerfile` · `8081` |
| **Web full Flutter (legacy)** | `--dart-define=WEB_MODE=full` | `apps/mobile/FullWeb.Dockerfile` · `8082` |
| **Admin** | React/Vite | `apps/admin/Dockerfile` · `3000` |
| **App** | APK/AAB/IPA từ GitHub Release | — |

Next.js web build tĩnh:

```bash
cd apps/web
NEXT_PUBLIC_API_URL=https://api.example.com npm run build
# output: apps/web/out
docker build -f apps/web/Static.Dockerfile -t sharee-web .
```

Web mobile giữ khung điện thoại; Next.js web là bản desktop/web chính.

## Báº£n Ä‘á»“ & APK

- Tile URL cáº¥u hÃ¬nh: `--dart-define=MAP_TILE_URL=... --dart-define=MAP_ATTRIBUTION=...`.
- Self-host OSM: [infra/maps/README.md](infra/maps/README.md), cháº¡y `infra/scripts/setup-map.ps1`.
- APK release: `cd apps/mobile && flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com`.
- Keystore: `infra/scripts/create-keystore.ps1`; `key.properties` vÃ  keystore khÃ´ng commit.
- Android SDK chuáº©n: `flutter config --android-sdk C:\Android\sdk`.

## Auto release Android + iOS

Workflow [`.github/workflows/release.yml`](.github/workflows/release.yml) build APK/AAB/IPA vÃ  táº¡o GitHub Release khi push tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Cáº§n secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
`ANDROID_KEY_PASSWORD`; iOS/TestFlight vÃ  Firebase lÃ  tuá»³ chá»n. HÆ°á»›ng dáº«n:
[RELEASE.md](RELEASE.md).

## Production

```bash
cp .env.example .env            # Ä‘iá»n secrets tháº­t
docker compose -f infra/compose/docker-compose.prod.yml --env-file .env up -d --build
```

- KhÃ´ng seed demo, táº¯t OTP dev/Swagger/mock payment, DB/Redis khÃ´ng má»Ÿ port.
- API/admin bind `127.0.0.1`, Ä‘áº·t sau reverse proxy TLS; báº­t WebSocket cho `/hubs/*`.
- Táº¡o admin Ä‘áº§u tiÃªn báº±ng `POST /api/auth/bootstrap-admin` + header `X-Bootstrap-Token`,
  sau Ä‘Ã³ xoÃ¡ token.
- Chi tiáº¿t checklist, backup, scale, blocker: [PRODUCTION.md](PRODUCTION.md).

## Ghi chÃº

- Cáº¥u hÃ¬nh máº·c Ä‘á»‹nh trong repo lÃ  **demo**: OTP tráº£ vá» client, thanh toÃ¡n mock.
- Production tá»± cháº·n mock payment, OTP dev, Swagger vÃ  seed demo; xem `PRODUCTION.md`.
- Flutter web gá»i API qua `localhost:8080`; Ä‘á»•i báº±ng `--dart-define=API_BASE_URL=...`.
- Android SDK chuáº©n Ä‘Ã£ cáº¥u hÃ¬nh táº¡i `C:\Android\sdk`; APK build táº¡i
  `apps/mobile/build/app/outputs/flutter-apk/`, báº£n kÃ½ sáºµn trong `artifacts/sharee-release-signed.apk`.
- Build APK store: táº¡o keystore báº±ng `infra/scripts/create-keystore.ps1`, rá»“i
  `flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com`.

