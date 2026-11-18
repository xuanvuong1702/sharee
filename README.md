# Sharee — ứng dụng đi chung xe (BlaBlaCar-style) + chế độ Daily

Đồ án học tập được triển khai đầy đủ: **backend ASP.NET Core 10 + PostgreSQL/PostGIS**, **Flutter mobile app**,
**React admin**, **Docker Compose**, migration/seed tự động, unit test và smoke test end-to-end.

> Cấu hình trong repo là **demo**, bật OTP dev, seed dữ liệu mẫu và thanh toán mock.
> Trước khi chạy cho khách thật, đọc [PRODUCTION.md](PRODUCTION.md) và dùng `infra/compose/docker-compose.prod.yml`.

## Giao diện

> **Thiết kế mới cho mô hình chợ chuyến đi thương lượng giá nằm tại [docs/desgin/README.md](docs/desgin/README.md).**
> Phần mô tả bên dưới là app hiện tại (carpooling/Daily, giá cố định) — chưa phải UI đích.

- Design system riêng: palette navy/electric blue, thang chữ, radius 20–28, shadow mềm, trạng thái màu thống nhất.
- Mobile-first: app bar gọn, bottom nav nổi 5 tab, sticky CTA, bottom sheet, safe-area và vùng chạm ≥ 44px.
- Trải nghiệm: skeleton loading, pull-to-refresh, empty state có hành động, transition mượt, haptic feedback.
- Bản web được đóng khung 480px như một chiếc điện thoại để kiểm chứng UI trên desktop.

## Chạy trong 1 lệnh

```bash
docker compose up -d --build
```

| Dịch vụ | URL | Ghi chú |
|---|---|---|
| API + Swagger | http://localhost:8080/swagger | REST + SignalR `/hubs/chat`, `/hubs/notifications` |
| Admin web | http://localhost:3000 | đăng nhập bằng OTP admin |
| Mobile web (Flutter) | http://localhost:8081 | bản build web của app Flutter |
| PostgreSQL/PostGIS | localhost:5432 | user/pass/db: `sharee` |
| Redis | localhost:6379 | SignalR backplane + cache |

Health checks: `GET /health/live`, `GET /health/ready` (DB readiness), `GET /health` (tương thích cũ).

> Nếu build mobile web lần đầu: `cd apps/mobile && flutter build web --dart-define=API_BASE_URL=http://localhost:8080`
> trước khi `docker compose up --build` (Dockerfile copy `build/web`).

## Tài khoản demo

OTP được trả về trong response (`devCode`) khi `Auth:ExposeOtp=true` (mặc định trong demo).

| Vai trò | Số điện thoại |
|---|---|
| Admin | `+84900000001` |
| Hành khách | `+84912345678` (Minh) |
| Tài xế | `+84912000001` (Trung Kiên) |
| Tài xế | `+84912000002` (Minh Hằng) |

Seed sẵn 4 chuyến Hà Nội → Hải Phòng/Nội Bài (ngày mai, giờ Việt Nam), 1 tuyến Daily ở TP.HCM
(Bến Thành – Suối Tiên, 6 trạm), báo cáo và hồ sơ chờ duyệt.

> Tài xế demo phải hoàn tất xác thực trong app trước khi đăng chuyến/nhận booking.

## Kiến trúc

```text
Flutter app ──┐
React admin ──┼── HTTP/JSON ──▶ ASP.NET Core minimal API
              │                  ├─ Auth (OTP + JWT)
              │                  ├─ Trips / Search (PostGIS)
              │                  ├─ Bookings (atomic seat hold)
              │                  ├─ Payments + double-entry ledger
              │                  ├─ Chat (REST + SignalR)
              │                  ├─ Reviews / Reports / Admin
              │                  └─ Daily (lines, e-tickets, validations)
              │                        │
              │                  PostgreSQL + PostGIS
              │                  Redis (optional)
              └───────────────── SignalR /hubs/chat
```

### Quyết định kỹ thuật

- **PostGIS** cho tìm chuyến theo stop: `ST_DWithin` trên `trip_stops.location`, ghép cặp stop
  `pickup.seq < dropoff.seq`; giá chặng = `price_from_origin(drop) - price_from_origin(pick)`.
- **Giữ ghế nguyên tử**:
  `UPDATE trips SET seats_available = seats_available - @n WHERE id=@id AND seats_available >= @n`
  trong cùng transaction với insert booking; idempotency key chống đặt trùng.
- **Sổ cái kép**: mỗi giao dịch có `ledger_transactions` + các dòng D/C cân bằng; hoàn tiền ghi bút toán đảo.
- **Refresh token** xoay vòng: access token 60 phút (production 15 phút), refresh 30 ngày, revoke khi logout.
- **Outbox worker** đánh dấu event đã xử lý; notifications ghi trong cùng transaction.
- **Daily**: tuyến + trạm + QR/e-ticket 30 phút; tài xế nhận vé, xác nhận bằng mã 4 số; trợ giá theo km.
- **Chuyến định kỳ**: lịch chạy theo tuần, tự materialize chuyến cho 14 ngày tới, worker gia hạn mỗi 6 giờ.
- **Thu nhập tài xế**: tổng hợp booking hoàn thành (VND) và Daily (EUR), màn hình ví trong app.
- **Theo dõi trực tiếp**: bản đồ OpenStreetMap, vị trí tài xế + khách, route, ETA, trạng thái chuyến;
  driver chia sẻ GPS (hoặc mô phỏng khi trình duyệt chặn quyền), client cập nhật mỗi 3 giây.
- **Chat realtime**: SignalR `/hubs/chat`, lịch sử tin nhắn lưu PostgreSQL (tải lại vẫn còn), thread list tự cập nhật.
- **Notification realtime**: SignalR `/hubs/notifications` + outbox worker, badge số chưa đọc trên trang chủ.
- **Audit log** cho duyệt hồ sơ, xử lý báo cáo và hoàn tiền thủ công.

## Xác thực tài xế

- Tài khoản mới ở cấp 1 (đã xác thực số điện thoại). Muốn đăng chuyến/nhận booking phải được duyệt lên **cấp 3**.
- Hồ sơ bắt buộc: CCCD mặt trước/sau, GPLX mặt trước/sau, đăng ký xe, bảo hiểm xe và ảnh selfie.
- Ảnh/PDF tối đa 10 MB, kiểm tra magic bytes (JPEG/PNG/PDF), lưu ngoài web root, chỉ admin có quyền tải.
- Kiểm tra trùng số CCCD/GPLX, tuổi 18–80, giấy tờ còn hạn, ngày duyệt không vượt hạn giấy tờ.
- Tài xế chưa duyệt bị chặn tại API khi: đăng chuyến, tạo chuyến định kỳ, nhận booking, nhận/validate vé Daily.
- Admin duyệt/từ chối/tạm dừng, bắt buộc lý do khi từ chối; worker tự chuyển hồ sơ hết hạn sang `expired` và hạ cấp.
- Hồ sơ đã duyệt không sửa được; bị từ chối có thể sửa và gửi lại.
- API: `GET/PUT /api/me/verification`, `POST /api/me/verification/documents/{type}`, `POST /api/me/verification/submit`;
  admin: `GET /api/admin/verifications`, `GET /api/admin/verifications/{userId}`, duyệt/từ chối/tạm dừng.
- Lưu trữ: `Storage__VerificationRoot` (Docker volume `sharee-verifications:/data/verifications`), phải backup cùng DB.

## Escrow, khiếu nại & uy tín

- **Escrow**: mỗi booking có `escrow_holds` với số tiền, phương thức và trạng thái
  `held → released/refunded`, hoặc `disputed` khi có khiếu nại. Tiền chỉ giải ngân khi tài xế hoàn tất và không có khiếu nại mở.
- **Phương thức**: chuyển khoản ngân hàng, ví điện tử qua PayOS, hoặc tiền mặt khi lên xe.
  Tiền mặt yêu cầu khách đã KYC cấp ≥2; escrow ghi `cash_pending` và đóng khi hoàn tất.
- **Khiếu nại**: một khiếu nại mở/booking; tiền escrow bị khóa (`disputed`).
  Hai bên tải bằng chứng ảnh/PDF (tối đa 10 MB), admin xem cả hai phía và quyết định
  `release` hoặc `refund`. Hoàn tất chuyến bị chặn khi còn khiếu nại mở.
- **Uy tín**: `GET /api/me/reputation` và `/api/users/{id}/reputation` trả điểm 0–100,
  hạng `new/bronze/silver/gold/elite`, tỷ lệ hoàn thành, số đơn, đánh giá và huy hiệu KYC/tài xế.
- Điểm = 50% đánh giá + 35% tỷ lệ hoàn thành + 15% số giao dịch (tối đa ở 20 đơn).
- Lưu bằng chứng khiếu nại tại `Storage:AppealRoot` (volume `sharee-appeals:/data/appeals`); backup cùng DB.
- API: `GET /api/bookings/{id}/escrow`, `POST /api/bookings/{id}/payment-method`,
  `POST /api/bookings/{id}/appeals`, `POST /api/appeals/{id}/evidence`;
  admin: `GET /api/admin/appeals`, `POST /api/admin/appeals/{id}/resolve`.

## API chính

```
POST /api/auth/otp/request            {phone} -> {expiresIn, devCode}
POST /api/auth/otp/verify             {phone, code} -> {accessToken, refreshToken, user}
POST /api/auth/refresh                {refreshToken} -> token mới
POST /api/auth/logout                 revoke refresh token
GET  /api/me
GET  /api/me/earnings                 thu nhập tài xế (chuyến + Daily)
GET  /api/trips/search?fromLat&fromLng&toLat&toLng&date&seats
GET  /api/trips/{id}
POST /api/trips                       (driver)
POST /api/trips/recurring             lịch chạy theo tuần
GET  /api/trips/recurring
DELETE /api/trips/recurring/{id}      tạm dừng
GET  /api/trips/{id}/tracking         vị trí tài xế/khách + ETA + route
POST /api/trips/{id}/location         cập nhật GPS (driver/passenger)
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

Swagger đầy đủ: http://localhost:8080/swagger

## Cấu trúc repo

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
  maps/                    self-host OSM tile server
  scripts/
    smoke.ps1              smoke test end-to-end
    oversell.ps1           concurrent booking test
    create-keystore.ps1    Android upload keystore
```

## Phát triển

```bash
# Backend (cần Postgres/Redis từ compose)
dotnet run --project backend/src/Sharee.Api

# Flutter
cd apps/mobile
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080

# Flutter Android (emulator dùng 10.0.2.2)
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

## Kiểm thử

```bash
dotnet test backend/tests/Sharee.Tests
cd apps/mobile && flutter test
powershell -File infra/scripts/smoke.ps1
powershell -File infra/scripts/oversell.ps1
```

- `smoke.ps1`: đăng nhập OTP → tìm chuyến → đặt 1 ghế → thanh toán → chat → tạo vé Daily → tài xế xác nhận.
- `oversell.ps1`: bắn 6 request đặt ghế đồng thời, assert không bán quá số ghế (201 = 1, 409 = 5).
- `node tools/uicheck/realtime-check.mjs`: kiểm tra chat realtime, lịch sử lưu DB và notification realtime.

## Thanh toán PayOS

- Mobile gọi `POST /api/bookings/{id}/payos`, nhận `checkoutUrl` + QR, mở PayOS và poll trạng thái booking.
- Webhook `POST /api/payments/payos/webhook` xác minh HMAC-SHA256, chốt booking + ledger idempotent.
- Bật production:

```env
Payments__Provider=payos
PayOS__Enabled=true
PayOS__ClientId=...
PayOS__ApiKey=...
PayOS__ChecksumKey=...
PayOS__ReturnUrl=https://app.example.com/payment/return
PayOS__CancelUrl=https://app.example.com/payment/cancel
```

- Demo dùng mock; production tự chặn mock.
- Kiểm thử gateway giả: `node tools/uicheck/payos-check.mjs`.

## Tip / donate cho tài xế

- Tài xế cấu hình **BIN ngân hàng + số tài khoản + tên chủ tài khoản** trong Hồ sơ → **Nhận tip**.
- QR được sinh trực tiếp theo chuẩn **VietQR/NAPAS 247**, không phụ thuộc dịch vụ ảnh QR bên thứ ba.
- Hành khách có thể tip sau khi chuyến **hoàn thành**:
  - **Chuyển khoản/QR**: tài xế nhận thông báo, khách báo đã chuyển, tài xế xác nhận;
  - **Tiền mặt**: ghi nhận ngay và thông báo cho tài xế.
- Thông báo realtime qua SignalR + push (nếu cấu hình FCM/APNs).
- Thu nhập tip hiển thị trong **Thu nhập** và **Tip đã nhận**.

API chính:
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

Tip chuyển khoản/tiền mặt đi **trực tiếp** giữa khách và tài xế, Sharee chỉ ghi nhận và thông báo.
Muốn thu tiền qua nền tảng (PayOS) thì cần bổ sung luồng thanh toán/đối soát riêng.

## Push FCM / APNs

- Backend: FCM HTTP v1 + APNs HTTP/2, device token API, outbox gửi push sau notification.
- Mobile: `firebase_core` + `firebase_messaging`, token tự đăng ký sau đăng nhập.
- Cấu hình mobile:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=...
```

- Backend: `Push__Fcm__ProjectId`, service account JSON (hoặc file trong container), APNs key nếu dùng trực tiếp.
- Chi tiết: [PRODUCTION.md](PRODUCTION.md).

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

## Bản đồ & APK

- Tile URL cấu hình: `--dart-define=MAP_TILE_URL=... --dart-define=MAP_ATTRIBUTION=...`.
- Self-host OSM: [infra/maps/README.md](infra/maps/README.md), chạy `infra/scripts/setup-map.ps1`.
- APK release: `cd apps/mobile && flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com`.
- Keystore: `infra/scripts/create-keystore.ps1`; `key.properties` và keystore không commit.
- Android SDK chuẩn: `flutter config --android-sdk C:\Android\sdk`.

## Auto release Android + iOS

Workflow [`.github/workflows/release.yml`](.github/workflows/release.yml) build APK/AAB/IPA và tạo GitHub Release khi push tag:

```bash
git tag v1.1.2
git push origin v1.1.2
```

Cần secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
`ANDROID_KEY_PASSWORD`; iOS/TestFlight và Firebase là tuỳ chọn. Hướng dẫn:
[RELEASE.md](RELEASE.md).

## Production

```bash
cp .env.example .env            # điền secrets thật
docker compose -f infra/compose/docker-compose.prod.yml --env-file .env up -d --build
```

- Không seed demo, tắt OTP dev/Swagger/mock payment, DB/Redis không mở port.
- API/admin bind `127.0.0.1`, đặt sau reverse proxy TLS; bật WebSocket cho `/hubs/*`.
- Tạo admin đầu tiên bằng `POST /api/auth/bootstrap-admin` + header `X-Bootstrap-Token`,
  sau đó xoá token.
- Chi tiết checklist, backup, scale, blocker: [PRODUCTION.md](PRODUCTION.md).

## Ghi chú

- Cấu hình mặc định trong repo là **demo**: OTP trả về client, thanh toán mock.
- Production tự chặn mock payment, OTP dev, Swagger và seed demo; xem `PRODUCTION.md`.
- Flutter web gọi API qua `localhost:8080`; đổi bằng `--dart-define=API_BASE_URL=...`.
- Android SDK chuẩn đã cấu hình tại `C:\Android\sdk`; APK build tại
  `apps/mobile/build/app/outputs/flutter-apk/`, bản ký sẵn trong `artifacts/sharee-release-signed.apk`.
- Build APK store: tạo keystore bằng `infra/scripts/create-keystore.ps1`, rồi
  `flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com`.

