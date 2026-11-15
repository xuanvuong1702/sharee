# Đánh giá production — Sharee

Cập nhật: 2026-11-14. Phạm vi: backend, mobile, thanh toán, push, bản đồ, build Android, hạ tầng.
Theo yêu cầu, **pháp lý và vận hành production được bỏ qua** trong đánh giá này.

## Kết luận

**Đạt mức production-candidate / pilot có kiểm soát, chưa phải production công khai đầy đủ.**
Toàn bộ luồng kỹ thuật đã có code thật và đã kiểm chứng bằng gateway/FCM giả hoặc môi trường thật ở
phần có thể. Các điều kiện còn lại chủ yếu là **credentials, cấu hình Firebase/PayOS thật, dung lượng
map tile, ký số store và kiểm thử tải** — không còn mock trong code production.

## Ma trận

| Hạng mục | Trạng thái | Bằng chứng / điều kiện |
|---|---|---|
| Auth OTP | ✅ | OTP hash HMAC trong DB, rate limit, Twilio adapter; test 429/verify |
| JWT / refresh | ✅ | Access 60 phút (prod 15), refresh xoay vòng, reuse revoke family |
| Phân quyền | ✅ | Admin policy, participant checks cho chat/tracking |
| Đặt ghế / ledger | ✅ | Atomic update, idempotency, oversell test 201=1/409=5 |
| PayOS | ✅ code, ⚠️ credentials | Tạo link + webhook chữ ký + settlement ledger; test bằng PayOS giả |
| Hoàn tiền PayOS | ⚠️ | Ledger refund có; **chưa gọi API refund PayOS** |
| FCM/APNs | ✅ code, ⚠️ credentials | FCM HTTP v1 + APNs ES256; device token API; chưa gửi thật do thiếu Firebase/APNs key |
| Realtime chat/noti | ✅ | SignalR + Redis backplane; chat persisted; notification badge |
| Tracking | ✅ | Map, GPS, ETA, trạng thái; OSM demo tiles |
| Tip tài xế | ✅ | VietQR/NAPAS 247, tiền mặt, xác nhận, notification, earnings |
| Bản đồ | ⚠️ | Tile URL cấu hình được; self-host stack có script; import Việt Nam chưa hoàn tất do dung lượng |
| Android SDK | ✅ | SDK chuẩn mới tại `C:\Android\sdk`; debug + release APK build thành công |
| APK release | ✅ ký local | `app-release.apk` ký upload keystore; chưa phát hành store |
| CI | ✅ | GitHub Actions build/test/audit/Docker |
| Security headers / CORS / rate limit | ✅ | Kiểm chứng header, CORS, 429 |
| Migrations | ✅ | Advisory lock, seed gating, 10 migrations |
| Backup/HA/load test | ⚠️ ngoài phạm vi | Chưa triển khai/đo |
| Pháp lý / vận hành | — | Bỏ qua theo yêu cầu |

## Đã triển khai trong đợt này

### 1. PayOS
- `POST /api/bookings/{id}/payos` tạo payment link, lưu `payments` trạng thái `requires_capture`.
- Chữ ký tạo link: HMAC-SHA256(`amount&cancelUrl&description&orderCode&returnUrl`).
- Webhook `POST /api/payments/payos/webhook`:
  - xác minh chữ ký trên toàn bộ `data` đã sort;
  - idempotent theo `orderCode`;
  - xác nhận booking, ghi double-entry ledger, tạo conversation, notification.
- `GET /api/payments/config` để mobile chọn PayOS/mock.
- Production chặn mock; thiếu credential PayOS sẽ fail-fast.
- Đã test end-to-end với PayOS giả: tạo checkout → webhook → booking `confirmed`, payment `succeeded`.
- Webhook sai chữ ký trả **400**.

### 2. FCM / APNs
- Bảng `device_tokens`, API đăng ký/xoá token.
- `PushService`:
  - FCM HTTP v1 với service account JWT RS256, cache access token;
  - APNs HTTP/2 ES256 trực tiếp (tuỳ chọn), raw JOSE signature;
  - tự xoá token unregistered.
- Outbox worker gửi SignalR + push sau mỗi notification.
- Mobile `firebase_core`/`firebase_messaging`, token registration, cấu hình qua dart-defines.
- Android `POST_NOTIFICATIONS`; iOS `remote-notification` background mode.
- ⚠️ Chưa gửi thật vì chưa có Firebase project/service account/APNs key.

### 3. Android SDK / APK
- Cài SDK chuẩn mới tại `C:\Android\sdk` (platform 36, build-tools 36, NDK 28.2, CMake 3.22).
- `flutter config --android-sdk C:\Android\sdk`; build debug và **release APK thành công**.
- Gradle signing config đọc `key.properties`; script tạo upload keystore.
- APK release ký bằng keystore local (không commit keystore/password); bản ký nằm ở
  `artifacts/sharee-release-signed.apk` (chứng chỉ `CN=Sharee`).
- Lưu ý: APK hiện build với `API_BASE_URL=http://10.0.2.2:8080`; build store cần HTTPS.

### 4. Bản đồ
- `MapConfig` cho tile URL/attribution/user agent qua dart-define.
- Hỗ trợ Mapbox/MapTiler/Goong hoặc self-host.
- `maps/docker-compose.yml` + `scripts/setup-map.ps1` cho tile server OSM Việt Nam.
- Đã thử import nhưng máy hết dung lượng; script sẵn sàng, cần ≥8GB trống.
- Demo vẫn dùng OSM public tiles — **không dùng cho production tải cao**.

## Ba vòng rà soát

### Vòng 1 — Bảo mật & thanh toán
- Phát hiện: OTP plaintext/RAM, JWT 7 ngày, CORS mở, mock payment, refresh reuse.
- Đã sửa: OTP DB hash + pepper; JWT ngắn; CORS allowlist; PayOS thật; refresh family revoke;
  rate limit, security headers, body limit, bootstrap admin một lần.
- Test: OTP hash, 429, webhook signature, reuse 401.

### Vòng 2 — Kiến trúc & vận hành
- Phát hiện: worker trùng khi scale, booking hết hạn giữ ghế, migration race, container root.
- Đã sửa: SignalR Redis backplane, outbox `FOR UPDATE SKIP LOCKED`, BookingExpiryWorker 1 phút,
  MaintenanceWorker retention, advisory lock, non-root image, healthcheck, JSON logs.
- Test: realtime qua Redis, production-mode DB không seed, Swagger 404.

### Vòng 3 — Sản phẩm & UI
- PayOS QR sheet, polling trạng thái, fallback mock ở dev.
- Chat list dạng card, unread badge, route pill; chat realtime.
- Map attribution cấu hình; trạng thái tracking rõ ràng.
- APK release + signing scaffold; safe-area/scroll cho sheet thanh toán.
- Test: `flutter analyze` 0 error, `flutter test` 2/2, APK build.

## Chạy production

```bash
cp .env.example .env
# điền: DB/Redis password, JWT_KEY, OTP_PEPPER, Twilio, PayOS, FCM, origins
docker compose -f docker-compose.prod.yml --env-file .env up -d --build
```

Sau deploy:
1. `GET /health/ready` trả 200.
2. Bootstrap admin một lần bằng `X-Bootstrap-Token`, sau đó xoá token.
3. Cấu hình webhook PayOS trỏ tới `https://api.../api/payments/payos/webhook`.
4. Upload file Firebase service account, build mobile với FCM dart-defines.
5. Build APK/AAB bằng keystore thật và API HTTPS.
6. Chọn tile provider có SLA hoặc self-host tile server.

## Điều kiện còn lại trước khi mở công khai

1. **PayOS thật**: client id/key/checksum, webhook URL public, test giao dịch nhỏ; bổ sung API refund.
2. **Firebase/APNs thật**: tạo project, service account, `google-services.json`/`GoogleService-Info.plist`,
   build và test notification trên thiết bị thật; APNs key nếu dùng trực tiếp.
3. **Map tiles**: provider key hoặc self-host import đủ dữ liệu; cấu hình attribution/SLA.
4. **APK/AAB store**: ký bằng keystore production, API HTTPS, Firebase config, test trên thiết bị.
5. **Kiểm thử tải & backup**: ngoài phạm vi theo yêu cầu, nhưng vẫn là điều kiện vận hành.
6. **Pháp lý/eKYC**: bỏ qua theo yêu cầu.

## Bằng chứng kiểm thử hiện tại

- `dotnet test`: 8/8 pass; `flutter test`: 2/2 pass.
- PayOS fake gateway: checkout + webhook + settlement pass; sai chữ ký 400.
- Tip: tạo QR/tiền mặt, thông báo `tip.received`, khách báo đã chuyển, tài xế xác nhận,
  earnings và VietQR payload đã kiểm tra end-to-end.
- FCM device register: DB ghi nhận token; push disabled khi thiếu credential.
- Production-mode fresh DB: 0 users/trips, Swagger 404, health ready.
- APK debug/release build thành công; release ký cert `CN=Sharee`.
- Dependency audit: 0 lỗ hổng.
- Admin CSP hoạt động; API security headers và CORS allowlist đã kiểm tra.
