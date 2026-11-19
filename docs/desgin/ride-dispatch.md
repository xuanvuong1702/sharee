# ride-dispatch.md — Luồng đặt xe trực tiếp (v1.4)

> **Đây là luồng đang triển khai.** Các mục offer/counter trong `product.md`, `flows.md`, `screens.md` là **future mode**, không phải phạm vi hiện tại.
> Chủ dự án chốt: app **không can thiệp giá**, chỉ kết nối và hỗ trợ phương thức thanh toán.

## 1. Mô hình

```text
Passenger chọn điểm đón + điểm đến + loại xe + phương thức thanh toán
  → app hiển thị tài xế online gần đó
  → passenger bấm Đặt xe
  → các tài xế online nhận thông báo
  → tài xế đầu tiên nhận chuyến
  → tài xế đến / bắt đầu / hoàn tất
  → passenger và tài xế thanh toán trực tiếp
```

- App **không nhập giá**, không báo giá, không offer/counter trong bản này.
- Giá cước do passenger và tài xế tự thỏa thuận ngoài app.
- App ghi nhận **phương thức** (tiền mặt / chuyển khoản / ví) để hai bên phối hợp.
- Không escrow giá cước; không trừ tiền chuyến.
- Nếu sau này bật offer/counter, dùng tài liệu cũ và feature flag riêng.

## 2. Passenger flow

1. Home → hero `Đặt chuyến`.
2. Bản đồ mở; pickup mặc định vị trí hiện tại (hoặc Hà Nội nếu không có quyền).
3. Chọn điểm đón/đến:
   - Nhập tìm kiếm (Nominatim proxy, fallback địa điểm Hà Nội).
   - Hoặc chạm bản đồ; reverse geocode lấy địa chỉ.
4. Map fit pickup + tài xế gần; marker tài xế hiện trên map.
5. Chọn loại xe, phương thức thanh toán, ghi chú.
6. `Đặt xe` → tạo `ride_request` trạng thái `searching`.
7. Màn chờ:
   - `searching`: đang gửi đến tài xế.
   - `accepted`: tài xế đang đến, hiện tên/xe/biển số/đánh giá.
   - `arrived`: tài xế đã đến.
   - `in_progress`: đang di chuyển.
   - `completed`: hoàn tất, thanh toán trực tiếp.
8. Có thể huỷ trước khi hoàn tất.

## 3. Driver flow

1. Profile → `Chế độ tài xế`.
2. Bật online; app cập nhật presence + vị trí.
3. Nhận danh sách chuyến `searching` gần (poll 3s + notification).
4. Xem pickup/dropoff, phương thức thanh toán, ghi chú, đánh giá khách.
5. `Nhận chuyến` → race-safe, chỉ một tài xế thắng.
6. Cập nhật:
   - `arrive` → đã đến điểm đón.
   - `start` → bắt đầu chuyến.
   - `complete` → hoàn tất; xác nhận đã thu tiền.
7. Thu tiền trực tiếp theo phương thức đã chọn.

## 4. API hiện có

```text
GET  /api/geo/search?q=
GET  /api/geo/reverse?lat=&lng=
GET  /api/drivers/nearby?lat=&lng=&radiusKm=
GET  /api/driver/presence
PUT  /api/driver/presence
GET  /api/driver/rides/incoming
GET  /api/driver/rides/current
POST /api/rides
GET  /api/rides/{id}
GET  /api/rides/mine
POST /api/rides/{id}/accept
POST /api/rides/{id}/arrive
POST /api/rides/{id}/start
POST /api/rides/{id}/complete
POST /api/rides/{id}/cancel
```

## 5. Dữ liệu

- `driver_presence`: online, location, vehicle, updated_at.
- `ride_requests`: pickup/dropoff, labels, vehicle_class, payment_method, note, status, driver_id, timestamps.
- Không có cột giá cước trong `ride_requests`.
- Notification `ride.request` gửi cho tài xế online.
- Notification `ride.accepted/arrived/started/completed/cancelled` gửi cho passenger.

## 6. Bản đồ

- Tile: Esri Light Gray Canvas (ổn định, không cần API key).
- Attribution: Esri/HERE/Garmin/OSM.
- Marker: pickup teal, destination amber, tài xế icon taxi.
- Search: Nominatim proxy + cache + fallback nội bộ.
- Map tap → reverse geocode; nếu lỗi vẫn giữ toạ độ.

## 7. Bảo mật & tin cậy

- Chỉ tài xế có xe active + KYC approved mới online/nhận chuyến.
- Chỉ passenger đã đăng nhập mới tạo chuyến.
- Không trả SĐT đầy đủ; `phoneMasked`.
- Accept dùng `UPDATE ... WHERE status='searching'` để tránh 2 tài xế nhận cùng chuyến.
- Không lưu/giữ tiền cước.

## 8. Giới hạn hiện tại

- Chưa có route line/ETA đường đi; ETA tài xế là ước lượng khoảng cách.
- Chưa có chat/call trong chuyến mới.
- Chưa có rating sau chuyến mới.
- Chưa có huỷ có phí.
- Driver mode dùng poll 3s; production nên SignalR/push.
- Seed tài xế online phục vụ demo; production cần tài xế thật bật online.
- Chưa có nhiều điểm dừng, đặt lịch, xe hợp đồng.

## 9. Acceptance checklist

- [x] Chọn điểm đón/đến bằng nhập hoặc map.
- [x] Map hiện tài xế gần sau khi chọn điểm.
- [x] Đặt xe gửi thông báo tới tài xế online.
- [x] Tài xế nhận chuyến; passenger thấy trạng thái.
- [x] Tài xế arrive/start/complete.
- [x] Không có giá do app đặt.
- [x] Có chọn phương thức thanh toán; thanh toán trực tiếp.
- [x] Không lưu giá cước/escrow.
- [ ] Chat/call trong chuyến mới.
- [ ] Rating sau chuyến mới.
- [ ] Route line/ETA giao thông.
