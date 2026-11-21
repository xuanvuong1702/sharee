# hardening.md — Trạng thái sửa lỗi P0/P1

> Cập nhật 2026-11-21. Không thay thế danh sách audit gốc; đây là trạng thái triển khai.

## Đã sửa

### P0 — tiền

- **Một đường settlement duy nhất:** `BookingSettlementService` xử lý complete, confirm, release, refund. `BookingEndpoints /complete` và `TrackingService` không còn mỗi nơi tự ghi payout.
- **Holdback 2 giờ:** tài xế hoàn tất → booking `completed`, escrow `held`, `release_at = now()+2h`. Passenger xác nhận qua `POST /api/bookings/{id}/confirm` hoặc worker `BookingReleaseWorker` giải ngân sau 2 giờ.
- **Tracking không còn payout:** tracking chỉ là tín hiệu vị trí/trạng thái, không thể tạo bút toán.
- **Chống payout/refund hai lần:** release kiểm tra payout ledger + trạng thái escrow; refund kiểm tra payout trước khi hoàn.
- **Partial refund:** huỷ 70%/0% ghi refund phần khách và phần còn lại vào `platform_revenue`; escrow `partial_refunded`/`refunded`, không còn tiền kẹt.
- **Late PayOS webhook:** booking đã rời `pending_payment` → ghi `payment_reconciliation` thay vì trả `false` im lặng; admin có queue `GET /api/admin/reconciliation`.
- **PayOS link expiry:** link không sống quá `bookings.expires_at`.
- **Admin refund thủ công:** chặn nếu đã payout, cập nhật escrow/payment, audit actor thật.
- **Ví tài xế / rút tiền:** ledger `driver_payable`; `GET /api/driver/wallet`, tạo yêu cầu rút, admin duyệt/đánh dấu đã chuyển khoản; UI **Ví tài xế** trong app.
- **Phí nền tảng:** `Platform:FeePercent` (mặc định 10%), ghi `fee_amount`, tách `driver_payable` và `platform_revenue` khi release.
- **PayOS refund adapter:** `PayOsService.RefundAsync`, bảng `payment_refunds`; nếu PayOS bật và gọi lỗi thì không đánh dấu refund thành công.
- **Lịch sử trạng thái:** trigger `booking_status_history` ghi mọi thay đổi status booking.

### P0 — PII / auth

- `/api/trips/{id}`, `/api/users/{id}`, `/api/users/{id}/reviews` yêu cầu đăng nhập.
- SĐT driver trong search/trip detail được mask; booking chỉ lộ SĐT khi `confirmed/completed`.
- User profile của người khác mask phone/email, bỏ bio; chủ tài khoản vẫn thấy đầy đủ.
- Daily driver queue yêu cầu KYC; vé `waiting` không trả `code`/`qr_token`.
- Daily validate: kiểm tra hạn vé, trạng thái, `failed_attempts` (tối đa 5), vị trí tài xế nếu có, mã CSPRNG.
- Idempotency key scope `(passenger_id, trip_id, key)`.
- Refresh token từ chối user `blocked` và thu hồi phiên.
- Forwarded headers chỉ tin proxy cấu hình; không clear trắng.
- Compose: DB/Redis bind `127.0.0.1`, API environment `Development`.

### P1 — ride/carpool/validation

- Ride dispatch chỉ gửi tài xế trong 12 km, tối đa 20, không gửi chính passenger.
- Ride `searching` hết hạn sau 15 phút (`RideExpiryWorker`).
- Presence chỉ hợp lệ 10 phút; driver app gửi heartbeat 2 phút/lần.
- Tài xế không nhận ride của mình, không nhận khi đang có ride active.
- Cancel chỉ khi `searching/accepted/arrived`, update có guard.
- Chỉ passenger hoặc tài xế được xem ride; không xem ride `searching` người khác.
- Giới hạn 2 ride active/passenger.
- Trip search: validate ngày, clamp seats/radius.
- Booking: chặn chuyến sắp/đã quá giờ, giới hạn pending/user/trip, giá tràn.
- Trip create: 2–20 stops, label, toạ độ, stop trùng, giá/ghế.
- Review/report/profile: giới hạn độ dài, target tồn tại, avatar http(s).
- Admin: IP allowlist + TOTP MFA tùy chọn (`Admin:AllowedIps`, `Admin:MfaSecret`).
- OTP: giới hạn theo IP + toàn cục (`OtpRateGuard`).
- Outbox: exponential backoff, dead-letter sau 5 lần (`dead_lettered_at`).

### Test

- Backend: **16 test pass**, gồm Testcontainers Postgres cho ledger invariant.
- Migrations 016–021 đã chạy trên server.
- API health 200 sau deploy.
- Ví/rút tiền đã test end-to-end: tạo yêu cầu → admin paid → số dư giảm.

## Chưa sửa / còn lại

### P0 còn lại

- **PayOS refund adapter chưa được xác minh với merchant thật** do chưa có credential; cần test sandbox trước production.
- **Chuyển khoản tài xế vẫn là admin đánh dấu đã chuyển**, chưa tích hợp bank payout API.
- **Chưa có state machine đầy đủ/event-sourced** cho mọi chuyển trạng thái; đã có guard chính và status history trigger.
- **Object storage + mã hoá CCCD/tài khoản ngân hàng** chưa có; file vẫn local volume.

### P1 còn lại

- Admin web refresh token; UI nhập MFA khi bật.
- Daily: tiền EUR/amount_minor, subsidy mặc định 200, khoảng cách 5 km, chưa có location bắt buộc.
- Rating tích luỹ `numeric(3,2)`.
- Tip cash tự confirm.
- Carpool schedule conflict, route engine thật, ETA.
- Outbox vẫn giữ transaction khi gửi push (chưa tách claim/process).

### P2/P3 còn lại

- N+1, phân trang, cache size, Redis health, timestamp behavior.
- Secure storage token, CSP, repo LFS, `desgin` typo.
- File KYC/appeal lên object storage; mã hoá CCCD/tài khoản ngân hàng.
- Bảng settings thay hard-code.
- Backup script, reconciliation UI đầy đủ.

> Ưu tiên tiếp theo: **xác minh PayOS refund sandbox + bank payout API + mã hoá/object storage**.
