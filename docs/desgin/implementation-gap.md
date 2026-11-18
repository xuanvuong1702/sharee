# implementation-gap.md — Khoảng cách thiết kế ↔ code hiện tại

> Mục đích: trước khi code, xác định rõ cái gì tái dùng, cái gì phải xây mới, thứ tự nào an toàn.

## 1. Codebase hiện tại

### Đang có

- ASP.NET Core + PostgreSQL/PostGIS + Redis.
- Auth OTP, JWT/refresh.
- `trips` + `trip_stops` + `bookings` giá cố định, ghế.
- Carpooling/Daily shuttle.
- KYC tài xế 7 giấy tờ, admin duyệt.
- Escrow ledger, payment mock/PayOS, refund.
- Khiếu nại + bằng chứng.
- Reputation.
- Admin React.
- Flutter passenger app + mobile web.
- Next.js consumer web.

### Không phù hợp mô hình mới

| Hiện tại | Mô hình mới | Kết luận |
|---|---|---|
| `trips` do tài xế tạo, giá cố định | Passenger tạo `RideRequest`; driver offer | Không dùng `trips` làm request |
| `bookings` đặt ghế | Chọn 1 offer → `Trip` | Booking flow khác |
| Giá do app/tài xế đặt | Hai bên thương lượng | Cần offer/counter domain |
| Không có driver mode | Driver online/radar/offer | Cần role + presence |
| Không có live dispatch | Broadcast request | Cần geo queue/notification |
| Carpool nhiều ghế | 1 passenger/chuyến (MVP) | Đơn giản hơn |
| Daily shuttle | Không thuộc MVP ride-hailing | Giữ riêng, không trộn |
| Không có ví/rút tiền | Driver earnings/withdraw | Cần ledger + payout |
| Khiếu nại sau chuyến | Tranh chấp cả trước/trong/sau | Mở rộng |
| KYC tài xế | Cần passenger KYC + driver | Tái dùng nền |

## 2. Tái dùng

- Auth/OTP/JWT.
- User/KYC/verification docs.
- Ledger/escrow/payment.
- Dispute/evidence.
- Reputation/rating.
- Notification/outbox/SignalR.
- Admin shell/KYC/dispute UI.
- Map tile config.
- Design tokens/font.

## 3. Domain mới

### Entities

```text
ride_request
  id, passenger_id, pickup (geography), dropoff (geography),
  pickup_label, dropoff_label, vehicle_class,
  requested_at, scheduled_at,
  pricing_mode ('ask'|'open'),
  proposed_fare, currency,
  note, status, expires_at,
  broadcast_radius_m, created_at, updated_at

ride_offer
  id, request_id, driver_id, vehicle_id,
  amount, currency, kind ('accept'|'counter'|'quote'),
  eta_pickup_min, eta_trip_min,
  message, status, expires_at, created_at

negotiation_event
  id, request_id, offer_id, actor_id, action,
  amount_before, amount_after, created_at

trip
  id, request_id, offer_id, passenger_id, driver_id, vehicle_id,
  agreed_fare, currency, payment_method,
  status, pickup, dropoff,
  accepted_at, arrived_at, started_at, completed_at,
  cancellation_reason, cancelled_by,
  distance_m, duration_s

driver_presence
  driver_id, vehicle_id, online, location, heading,
  last_seen_at, available

driver_wallet / payout
  driver_id, balance, pending, currency, ...

safety_event
  id, trip_id, actor_id, type ('sos'|'route_deviation'|'share'),
  location, status, created_at
```

### State enums

Xem `product.md §3`, `content-and-states.md`.

### API surface (high level)

```text
POST /api/ride-requests
GET  /api/ride-requests/{id}
POST /api/ride-requests/{id}/cancel
POST /api/ride-requests/{id}/offers
GET  /api/ride-requests/{id}/offers
POST /api/ride-offers/{id}/accept
POST /api/ride-offers/{id}/decline
POST /api/ride-offers/{id}/counter
POST /api/ride-offers/{id}/withdraw
POST /api/trips/{id}/arrive
POST /api/trips/{id}/start
POST /api/trips/{id}/complete
POST /api/trips/{id}/cancel
POST /api/trips/{id}/rate
POST /api/trips/{id}/dispute
GET  /api/driver/presence
PUT  /api/driver/presence
GET  /api/driver/requests
GET  /api/driver/earnings
POST /api/driver/withdrawals
```

## 4. Thứ tự triển khai

### Phase 0 — Design system

- Token, font, component primitives.
- Map/theme.
- App shell + tab bar.
- Không đổi backend.

### Phase 1 — Core request/offer

- Tables, API, events.
- Passenger request flow.
- Driver radar + offer.
- Offer list + accept.
- Trip lifecycle.
- Notification/SignalR.
- Admin trip list.

### Phase 2 — Money/trust

- Escrow online.
- Cash.
- Receipt.
- Driver wallet/withdraw.
- KYC passenger.
- Reputation integration.
- Dispute.

### Phase 3 — Safety/ops

- SOS, share trip, route deviation.
- Admin live ops.
- Support.
- Config.
- Audit.

### Phase 4 — Growth

- Scheduled.
- Promo.
- Referral.
- Multi-stop.

## 5. Migration strategy

- **Không sửa** bảng `trips/bookings` hiện tại để trở thành ride-hailing.
- Tạo bounded context mới `rides` với bảng riêng.
- Giữ carpooling/Daily như module riêng, feature flag.
- Dùng chung user/KYC/ledger/notifications.
- Admin thêm mục “Rides” bên cạnh “Carpool”.
- Mobile thêm role switch; không xoá màn cũ ngay.
- Khi ride-hailing ổn định, có thể archive carpooling UI.

## 6. Rủi ro

| Rủi ro | Giảm thiểu |
|---|---|
| Offer spam | rate limit, max 5 active/driver, block |
| Giá thấp gây bỏ chuyến | hiển thị cảnh báo, không chặn; driver tự quyết |
| Hai bên giao dịch ngoài app | escrow, chat template, cảnh báo, không chia sẻ SĐT |
| Driver KYC giả | admin review, unique ID, expiry, selfie |
| Tranh chấp giá | lưu negotiation events, receipt, chat |
| GPS yếu | fallback nhập tay, cache |
| Offer hết hạn khi đang chọn | lock optimistic + server check |
| Double accept | transaction/row lock |
| Cash no-show | deposit P1, rating penalty |
| SOS | live ops, 113, emergency contact |

## 7. Design acceptance before code

- [ ] Mọi màn P0 có spec.
- [ ] Mọi state offer/trip/payment có copy.
- [ ] Offer/counter rules chốt.
- [ ] Payment/escrow rules chốt.
- [ ] KYC passenger/driver chốt.
- [ ] Admin live ops/dispute spec.
- [ ] Token JSON valid.
- [ ] Component states.
- [ ] Accessibility checklist.
- [ ] Data model/API draft.
- [ ] Prototype flow review.

## 8. Những câu cần chốt trước khi code

Xem `decisions.md`. Mặc định đã chọn; nếu đổi, cập nhật docs trước.
