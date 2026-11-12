# Sharee — ứng dụng đi chung xe (BlaBlaCar-style) + chế độ Daily

Đồ án học tập được triển khai đầy đủ: **backend ASP.NET Core 10 + PostgreSQL/PostGIS**, **Flutter mobile app**,
**React admin**, **Docker Compose**, migration/seed tự động, unit test và smoke test end-to-end.

## Chạy trong 1 lệnh

```bash
docker compose up -d --build
```

| Dịch vụ | URL | Ghi chú |
|---|---|---|
| API + Swagger | http://localhost:8080/swagger | REST + SignalR `/hubs/chat` |
| Admin web | http://localhost:3000 | đăng nhập bằng OTP admin |
| Mobile web (Flutter) | http://localhost:8081 | bản build web của app Flutter |
| PostgreSQL/PostGIS | localhost:5432 | user/pass/db: `sharee` |
| Redis | localhost:6379 | cache/rate-limit (dự phòng) |

> Nếu build mobile web lần đầu: `cd mobile && flutter build web --dart-define=API_BASE_URL=http://localhost:8080`
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
- **Outbox worker** đánh dấu event đã xử lý; notifications ghi trong cùng transaction.
- **Daily**: tuyến + trạm + QR/e-ticket 30 phút; tài xế nhận vé, xác nhận bằng mã 4 số; trợ giá theo km.

## API chính

```
POST /api/auth/otp/request            {phone} -> {expiresIn, devCode}
POST /api/auth/otp/verify             {phone, code} -> {accessToken, user}
GET  /api/me
GET  /api/trips/search?fromLat&fromLng&toLat&toLng&date&seats
GET  /api/trips/{id}
POST /api/trips                       (driver)
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
GET  /api/admin/dashboard
GET  /api/admin/verifications
POST /api/admin/verifications/{id}/approve|reject
GET  /api/admin/reports
PATCH /api/admin/reports/{id}?status=resolved
GET  /api/admin/refunds
POST /api/admin/refunds/{bookingId}
```

Swagger đầy đủ: http://localhost:8080/swagger

## Cấu trúc repo

```
backend/
  src/Sharee.Api/          API, endpoints, services, migrations (embedded SQL)
  tests/Sharee.Tests/      unit test pricing/refund
mobile/                    Flutter app (Android/iOS/web)
admin/                     React + Vite admin
docker-compose.yml
scripts/smoke.ps1          smoke test end-to-end
```

## Phát triển

```bash
# Backend (cần Postgres/Redis từ compose)
dotnet run --project backend/src/Sharee.Api

# Flutter
cd mobile
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080

# Admin
cd admin
npm install
npm run dev
```

## Kiểm thử

```bash
dotnet test backend/tests/Sharee.Tests
cd mobile && flutter test
powershell -File scripts/smoke.ps1
```

Smoke test: đăng nhập OTP → tìm chuyến → đặt 2 ghế → thanh toán → chat → tạo vé Daily → tài xế xác nhận.

## Ghi chú

- Đây là **demo học tập**: OTP trả về client, thanh toán mô phỏng, không có KYC/escrow thật.
- Đổi JWT key và tắt `Auth:ExposeOtp` trước khi dùng thật.
- Flutter web gọi API qua `localhost:8080`; đổi bằng `--dart-define=API_BASE_URL=...`.
