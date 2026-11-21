# hardening.md — trạng thái triển khai

> Cập nhật 2026-11-21. Build/test: backend **18/18**, Next.js build pass.

## Đã hoàn thành

### Tìm chuyến theo địa điểm thực tế
- Mobile: bỏ cặp điểm cố định; chọn điểm đón/đến bằng tìm kiếm, bản đồ, vị trí hiện tại; đổi chiều.
- Web: `SearchBox` autocomplete `/api/geo/search`; gửi đúng `fromLat/fromLng/toLat/toLng`.
- Trang kết quả dùng đúng toạ độ đã chọn, không fallback preset khi có query.

### Đăng chuyến trên bản đồ
- Mobile `PublishScreen`: bản đồ chọn điểm đón/đến, polyline, marker; gửi stops theo toạ độ.
- Web `/publish`: chọn địa chỉ, xe, giờ, giá, số ghế; tạo trip qua API.

### Ví / tài chính
- `driver_withdrawals`, API ví/rút/duyệt/đã chuyển khoản.
- Phí nền tảng `Platform:FeePercent`, ledger tách `driver_payable`/`platform_revenue`.
- PayOS refund adapter + `payment_refunds`.
- Bank payout adapter + contract test mock.

### Bảo mật dữ liệu
- `SensitiveDataProtector` AES-256-GCM cho CCCD/GPLX/đăng ký xe và số tài khoản ngân hàng.
- Backfill idempotent khi khởi động.
- Token mobile chuyển sang `flutter_secure_storage`.
- Admin MFA TOTP + IP allowlist tùy chọn.
- OTP rate limit Redis (fallback memory).
- `/health/ready` kiểm tra DB + Redis.

### Object storage
- `ObjectStorageService` S3/MinIO, local fallback.
- KYC và appeal evidence lưu object storage; endpoint stream file.
- MinIO trong compose local.

### Booking state
- Trigger chặn transition sai + `booking_status_history`.
- Outbox claim batch bằng `UPDATE ... RETURNING`, gửi SignalR/push ngoài transaction; backoff + dead-letter.

### Hiệu năng / N+1
- `/bookings/mine` phân trang + một connection cho projection.
- `/trips/mine`, `/my-tickets` phân trang.
- Chat list gộp một query (user, last message, unread count, trip).
- Cache GeoService có `SizeLimit`.

### Dọn repo / tài liệu
- Xóa `desktop_sidebar.dart`, `full_web_home_screen.dart`; bỏ chế độ full web Flutter.
- Bỏ service `mobile-web` khỏi compose.
- Web đầy đủ là Next.js `apps/web`.
- README cập nhật.

## Còn phụ thuộc môi trường ngoài

- **PayOS refund sandbox**: adapter đã có contract test; cần `ClientId/ApiKey/ChecksumKey` sandbox và giao dịch thật để xác minh end-to-end.
- **Bank payout thật**: adapter đã có contract test; cần endpoint/API key của ngân hàng.
- **Object storage production**: MinIO local đã cấu hình; production cần endpoint/bucket/key thật.
- **Encryption key production**: đặt `SECURITY_DATA_KEY` đủ mạnh; nếu đổi key phải chạy re-encrypt migration.

## Lệnh kiểm tra

```bash
cd backend/tests/Sharee.Tests && dotnet test
cd apps/mobile && flutter analyze && flutter test
cd apps/web && npm run build
```
