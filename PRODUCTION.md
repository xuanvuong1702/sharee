# Đánh giá mức độ sẵn sàng production

Cập nhật: 2026-11-14. Phạm vi: backend, mobile, admin, hạ tầng Docker, bảo mật, vận hành.

## Kết luận

**Chưa thể chạy production cho khách hàng thật.** Phần lõi kỹ thuật đã được gia cố để đạt mức
"production-grade", nhưng còn **5 blocker bên ngoài code**:

1. **Thanh toán thật** — hiện là mock; production đã tự chặn mock (`Payments:AllowMock=false`).
2. **Push notification nền** — mới có realtime khi app đang mở; chưa có FCM/APNs.
3. **APK/IPA phát hành** — chưa build & ký được trong môi trường hiện tại.
4. **Bản đồ** — đang dùng tile OpenStreetMap công cộng, không phù hợp lưu lượng thương mại.
5. **Pháp lý & vận hành** — đăng ký kinh doanh vận tải, bảo hiểm, eKYC, backup/HA, giám sát 24/7.

Nếu chỉ chạy **pilot nội bộ** (ví dụ 20–50 tài khoản, thanh toán chuyển khoản thủ công), hệ thống
có thể triển khai được sau khi cấu hình secrets, SMS và backup.

## Ma trận đánh giá

| Hạng mục | Trạng thái | Ghi chú |
|---|---|---|
| Build / test / CI | ✅ Sẵn sàng | GitHub Actions build, test, audit dependency, build Docker |
| Auth OTP | ✅ Sẵn sàng (cần SMS) | OTP lưu DB dạng HMAC-SHA256, hết hạn 5 phút, tối đa 5 lần thử, cooldown/resend, rate limit; adapter Twilio |
| JWT / refresh | ✅ Sẵn sàng | Access 15–60 phút, refresh 30 ngày, xoay vòng, phát hiện reuse và revoke cả family |
| Phân quyền | ✅ Sẵn sàng | JWT role + policy admin; kiểm tra participant cho chat/tracking |
| Đặt ghế / sổ cái | ✅ Sẵn sàng | Atomic seat hold, idempotency, double-entry ledger, test oversell |
| Chat realtime | ✅ Sẵn sàng | SignalR + Redis backplane, lịch sử PostgreSQL |
| Notification realtime | ✅ Sẵn sàng | Outbox → SignalR user group, badge |
| Theo dõi chuyến | ✅ Sẵn sàng | GPS, ETA, route, trạng thái, retention vị trí 24h |
| Bảo mật HTTP | ✅ Sẵn sàng | Security headers, CORS theo cấu hình, rate limit, body limit, ProblemDetails, correlation ID |
| Secrets / config | ✅ Sẵn sàng | Không fallback JWT ở production; env bắt buộc; seed demo tắt |
| Migration | ✅ Sẵn sàng | Advisory lock, seed gating, index bổ sung |
| Container | ✅ Sẵn sàng | Non-root, healthcheck, restart policy, prod compose |
| Thanh toán | ⛔ Blocker | Chưa tích hợp cổng thật/webhook/reconciliation |
| Push nền | ⛔ Blocker | Chưa FCM/APNs |
| APK/IPA | ⛔ Blocker | Flutter web đã build; APK bị chặn NDK trên máy hiện tại |
| Bản đồ | ⚠️ Có điều kiện | OSM public tiles; cần Mapbox/Goong/self-host + SLA |
| eKYC | ⚠️ Có điều kiện | Admin duyệt thủ công; chưa có vendor eKYC/lưu trữ hồ sơ |
| Giám sát | ⚠️ Có điều kiện | Log JSON/correlation; chưa Prometheus/Grafana/Sentry/alert |
| Backup / HA | ⚠️ Có điều kiện | Chưa tự động backup; Postgres single-node |
| Hiệu năng | ⚠️ Chưa chứng minh | Chưa load test/Soak test |
| Pháp lý | ⛔ Blocker | Giấy phép vận tải, bảo hiểm, điều khoản, privacy |

## Đã gia cố trong đợt này

### Bảo mật
- OTP chuyển từ RAM sang bảng `otp_codes`, lưu **HMAC-SHA256 + pepper**, không lưu plaintext.
- Giới hạn: 1 lần gửi/60 giây (cấu hình), 10 lần/giờ, 5 lần nhập sai, hết hạn 5 phút.
- Adapter SMS: `dev` (log) hoặc **Twilio**; production từ chối provider dev.
- Rate limiting: global 300 request/phút/IP, auth 20 request/phút.
- JWT access token mặc định 60 phút (prod compose 15 phút), clock skew 30 giây.
- Refresh token xoay vòng, phát hiện dùng lại token cũ → revoke toàn bộ family.
- CORS theo `Cors:AllowedOrigins`, không còn `AllowAnyOrigin`.
- Security headers: nosniff, DENY frame, no-referrer, Permissions-Policy, COOP; HSTS ở production.
- Request body tối đa 2 MB; exception handler trả ProblemDetails, không lộ stack trace.
- Bootstrap admin một lần bằng `X-Bootstrap-Token`, không seed admin mặc định ở production.
- Mock payment bị chặn ở production (`Payments:AllowMock=false`).

### Vận hành
- `/health/live`, `/health/ready`; Docker healthcheck dùng `/health/ready`.
- Log có `X-Request-Id` + method/path/status/thời gian.
- Migration có PostgreSQL advisory lock, bỏ seed khi `Seed:DemoData=false`.
- Worker bảo trì: huỷ booking hết hạn và trả ghế, xoá OTP/refresh token cũ, xoá vị trí quá 24h,
  dọn outbox/notification.
- SignalR Redis backplane để scale nhiều API instance.
- API image chạy user `app` (non-root), có resource limit trong compose production.
- CI: build/test/audit dependency, Flutter analyze/test/build web, build Docker.
- Nâng cấp dependency vá lỗ hổng: Microsoft.OpenApi 2.7.5, SignalR Redis 10.0.15, MessagePack 2.5.303.

## Triển khai production

### 1. Chuẩn bị secrets

```bash
cp .env.example .env
# điền mật khẩu mạnh; KHÔNG commit .env
openssl rand -base64 48   # JWT_KEY
openssl rand -base64 24   # OTP_PEPPER
```

Bắt buộc: `POSTGRES_PASSWORD`, `REDIS_PASSWORD`, `JWT_KEY`, `OTP_PEPPER`,
`TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_FROM`, `APP_ORIGIN`, `ADMIN_ORIGIN`,
`API_PUBLIC_URL`.

Dùng mật khẩu chỉ gồm chữ/số nếu đặt trực tiếp trong connection string; ký tự `;` có thể phá
chuỗi kết nối. Với mật khẩu phức tạp, inject qua secret manager và URL-encode.

### 2. Khởi động

```bash
docker compose -f docker-compose.prod.yml --env-file .env up -d --build
```

Compose production:
- Không mở port DB/Redis ra ngoài.
- API/admin chỉ bind `127.0.0.1`, đặt sau reverse proxy TLS.
- Không seed dữ liệu demo.
- Tắt Swagger, mock payment, OTP dev.

### 3. TLS + reverse proxy

Dùng ALB/Nginx/Cloudflare làm TLS termination, forward:
- `X-Forwarded-For`, `X-Forwarded-Proto`
- WebSocket upgrade cho `/hubs/*`
- Giới hạn body, timeout phù hợp.

Mẫu Nginx:

```nginx
server {
  listen 443 ssl http2;
  server_name api.example.com;
  client_max_body_size 2m;
  location / {
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
  location /hubs/ {
    proxy_pass http://127.0.0.1:8080;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 3600s;
  }
}
```

Chỉ bật `ReverseProxy:TrustForwarded=true` khi proxy đáng tin cậy.

### 4. Tạo admin đầu tiên

```bash
curl -X POST https://api.example.com/api/auth/bootstrap-admin \
  -H "Content-Type: application/json" \
  -H "X-Bootstrap-Token: $BOOTSTRAP_TOKEN" \
  -d '{"phone":"+8490xxxxxxx","fullName":"Admin"}'
```

Sau đó **xoá `BOOTSTRAP_TOKEN`** khỏi môi trường và restart API.

### 5. Kiểm tra sau deploy

```bash
curl https://api.example.com/health/live
curl https://api.example.com/health/ready
```

Kỳ vọng: `200` và `{"status":"ready","db":true}`.

## Backup & khôi phục

```bash
# backup hằng ngày
docker compose -f docker-compose.prod.yml exec -T db \
  pg_dump -U sharee -Fc sharee > backup-$(date +%F).dump

# restore vào DB mới
pg_restore -d sharee backup-2026-11-14.dump
```

Yêu cầu tối thiểu:
- Backup tự động hằng ngày, giữ 14–30 ngày, lưu ngoài máy chủ.
- Diễn tập restore mỗi quý.
- Redis bật AOF (compose production đã bật).
- DB production nên dùng managed Postgres/PostGIS có PITR.

## Giám sát đề xuất

- Uptime: `/health/ready` từ 2 region.
- Log: tập trung (Loki/ELK), alert theo `X-Request-Id` khi lỗi 5xx.
- Metrics: request rate/latency/5xx, DB pool, Redis, SignalR connections, booking failures.
- Tracing: OpenTelemetry cho API + Npgsql + Redis.
- Alert: payment failures, outbox backlog, booking expiry, migration failure, disk > 80%.

## Scale

- API stateless; chạy nhiều replica sau load balancer.
- SignalR dùng Redis backplane; không cần sticky session.
- Postgres: connection pool mỗi instance; theo dõi `max_connections`.
- Redis: dùng managed/HA cho production.
- Outbox worker dùng `FOR UPDATE SKIP LOCKED`; booking expiry dùng CTE nguyên tử; recurring trip có
  unique index chống trùng. Có thể chạy nhiều replica, nhưng nên tách worker service riêng khi tải cao
  để API không bị ảnh hưởng.

## Blockers cần xử lý trước khi mở cho khách thật

### 1. Thanh toán
- Tích hợp VNPay/MoMo/Stripe; tạo payment intent, webhook có chữ ký, idempotency.
- Đối soát tự động với ledger; hoàn tiền qua API provider.
- Hiện `POST /api/bookings/{id}/pay` trả **501** ở production vì mock bị tắt.

### 2. Push notification
- FCM (Android) + APNs (iOS), lưu device token, gửi khi app đóng.
- Hiện chỉ realtime khi app mở.

### 3. Phát hành mobile
- Build APK/AAB release, ký keystore, upload store; bản hiện tại bị chặn NDK trên máy dev.
- Cấu hình `API_BASE_URL` HTTPS, không dùng cleartext.

### 4. Bản đồ
- OSM public tile không cam kết SLA và hạn chế thương mại.
- Dùng Mapbox/Goong/self-host tiles, cấu hình attribution và API key.

### 5. eKYC & pháp lý
- Vendor eKYC, lưu hồ sơ mã hoá, quy trình xoá dữ liệu.
- Điều khoản, chính sách riêng tư, bảo hiểm chuyến đi, tuân thủ quy định vận tải.

### 6. Vận hành
- Backup tự động + restore test.
- Monitoring/alerting 24/7.
- Load test mục tiêu (ví dụ 500 RPS tìm chuyến, 50 booking/s).
- Diễn tập sự cố DB/Redis.

## Tiêu chí sign-off production

- [ ] Không còn mock payment; webhook + đối soát chạy thật.
- [ ] SMS OTP hoạt động với số thật, không lộ mã.
- [ ] APK/IPA đã ký và test trên thiết bị thật.
- [ ] Backup/restore đã diễn tập.
- [ ] Monitoring + alert 5xx/latency/DB/Redis.
- [ ] Load test đạt SLO.
- [ ] eKYC + pháp lý hoàn tất.
- [ ] Bản đồ có SLA.
- [ ] Push notification nền.
- [ ] Worker scale-out an toàn.
