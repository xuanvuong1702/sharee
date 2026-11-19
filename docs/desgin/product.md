# product.md — Mô hình sản phẩm và luật nghiệp vụ

## 0. Phạm vi triển khai v1.4

> **Luồng đang code:** `ride-dispatch.md`. Không có trường giá cước; passenger chọn phương thức thanh toán; tài xế đầu tiên nhận chuyến; thanh toán trực tiếp. Các mục offer/counter bên dưới là **future mode**, chưa bật.


> Tài liệu này định nghĩa **cái gì** và **vì sao**, không định nghĩa pixel. Pixel nằm ở `screens.md`, `components.md`, `tokens.json`.

## 1. Định nghĩa

**RideRequest** — yêu cầu chuyến chưa chốt tài xế.

**RideOffer** — lời chào giá của tài xế cho một request.

**Trip** — chuyến đã chốt giữa passenger và driver, có giá khóa.

**Fare** — số tiền cuối cùng hai bên đồng ý, gồm cước + phụ phí đã khai báo + phí nền tảng (nếu có).

**Escrow** — tiền online được giữ bởi nền tảng/đối tác thanh toán đến khi chuyến hoàn tất hoặc tranh chấp được xử lý.

## 2. Actor & quyền

### Passenger

- Tạo request, sửa/huỷ trước khi có driver.
- Chọn “đặt giá” hoặc “để tài xế báo giá”.
- Nhận/từ chối/chấp nhận counter.
- Chọn 1 offer; sau đó không nhận offer khác.
- Chat/call sau khi match.
- Theo dõi, chia sẻ chuyến, SOS.
- Thanh toán online/cash; đánh giá; mở tranh chấp trong 24h.
- Lưu địa điểm, phương thức thanh toán, liên hệ khẩn cấp.

### Driver

- Bật/tắt online.
- Xem request trong bán kính; lọc loại xe/giá/khoảng cách.
- Accept giá hoặc counter/gửi quote.
- Nhận chuyến, navigate, arrive, start, complete.
- Huỷ có lý do; bị ảnh hưởng uy tín.
- Xem thu nhập, rút tiền, lịch sử.
- Chat/call sau match.
- Báo cáo sự cố, tranh chấp.

### Admin/Ops

- Xem live map, chuyến đang chạy, SOS.
- Duyệt/từ chối KYC, xe, giấy tờ.
- Xử lý tranh chấp, hoàn tiền, escrow.
- Khoá tài khoản/tài xế.
- Cấu hình offer validity, bán kính, phí nền tảng, chính sách huỷ.
- Audit mọi hành động.

### Support

- Tra cứu chuyến/người dùng.
- Gửi tin nhắn hỗ trợ.
- Tạo ticket hoàn tiền; không tự đổi giá.

## 3. Trạng thái cốt lõi

### RideRequest

```text
draft
  → searching
      → offers_received
          → negotiating
              → matched
              → expired
      → expired
      → cancelled
  → scheduled
      → searching (đến giờ)
  → cancelled
```

### RideOffer

```text
sent → viewed → accepted
           ↘ countered → accepted/declined/expired
           ↘ declined
           ↘ expired
           ↘ withdrawn
```

### Trip

```text
driver_assigned
  → driver_arriving
  → driver_arrived
  → in_progress
  → completed
  → paid
  → reviewed
  → closed
```

Nhánh:

```text
driver_assigned → cancelled_by_passenger
driver_assigned → cancelled_by_driver
driver_arriving → cancelled_by_passenger
in_progress → sos
in_progress → dispute
completed → dispute
```

### Payment

```text
pending
  → authorized (online escrow)
  → captured
  → released
  → refunded
  → failed
cash_due → cash_collected
```

## 4. Luật giá

1. **Không app-set price.** Không có bảng giá cố định theo km/phút.
2. Passenger nhập giá hoặc mở quote.
3. Giá tối thiểu: 0 < giá ≤ 10.000.000đ (config).
4. Driver counter phải khác giá hiện tại; hiển thị chênh lệch.
5. Offer chốt → giá khóa. Chỉ đổi nếu:
   - Passenger và driver cùng xác nhận phụ phí phát sinh (toll/parking) trước khi phát sinh.
   - Hoặc admin xử lý tranh chấp.
6. Không tự thêm phí nền tảng vào giá hiển thị; nếu có, hiển thị dòng riêng.
7. **MVP platform fee = 0%.** Có hook cấu hình cho tương lai.
8. Giá tham khảo không bắt buộc; nếu hiển thị, ghi rõ “tham khảo từ chuyến gần đây”, không tự điền.
9. Cash: giá vẫn khóa; tài xế thu đúng giá; passenger xác nhận đã trả.
10. Tolls/parking: tài xế khai báo trước; passenger đồng ý; nếu không, không được đòi.

## 5. Matching

### MVP

- Request broadcast đến tài xế online trong bán kính cấu hình (mặc định 5km).
- Tối đa 20 tài xế nhận request; tối đa 5 offer active/tài xế.
- Passenger xem danh sách offer, sort theo:
  - Giá thấp nhất
  - Đến sớm nhất
  - Uy tín cao nhất
- Passenger chọn thủ công. Không auto-accept.
- Khi chọn:
  - Offer accepted.
  - Các offer khác `declined`/`withdrawn`.
  - Request `matched`.
  - Tạo Trip, escrow hold nếu online.
  - Chat thread mở.
- Driver nhận thông báo “Bạn đã được chọn”, ETA đến pickup.

### Không làm trong MVP

- Auto-dispatch.
- Đấu giá tự động.
- Surge.
- Pool/shared ride.
- Multi-stop.

## 6. Offer rules

| Rule | Giá trị |
|---|---|
| Thời gian hiệu lực ask | 120 giây |
| Thời gian hiệu lực open | 180 giây |
| Counter/quote | 90 giây |
| Gia hạn ask | 1 lần, +60 giây |
| Tối đa offer/request | 20 |
| Tối đa active offer/driver | 5 |
| Khoảng cách broadcast | 5km (config) |
| Driver phải online | Có |
| Driver phải KYC approved | Có |
| Passenger phải phone verified | Có |
| Chat trước match | Chỉ template an toàn |
| Huỷ offer | Driver được rút trước khi passenger chọn |

### Counter-offer

- Tài xế thấy giá passenger; có thể nhập giá mới.
- Passenger thấy:
  - Giá tài xế.
  - Chênh lệch (+20.000đ).
  - ETA, rating, xe.
- Passenger có thể:
  - Chấp nhận.
  - Từ chối.
  - Gửi giá mới (1 lần).
- Mỗi bên tối đa 2 lượt counter; sau đó phải accept/decline.

## 7. Payment & escrow

### Phương thức

| Phương thức | Cách hoạt động | Escrow |
|---|---|---|
| **Ví Sharee** | Trừ số dư, giữ trong escrow | Có |
| **Ngân hàng/PayOS** | Chuyển khoản/QR, giữ escrow | Có |
| **Thẻ quốc tế** | P1 | Có |
| **Tiền mặt** | Trả trực tiếp khi hoàn tất | Không, nhưng ghi nhận |

### Release

- Online: escrow released khi driver hoàn tất + passenger xác nhận (hoặc auto sau 2h nếu không phản hồi).
- Cash: passenger xác nhận đã trả; driver xác nhận đã nhận.
- Nếu tranh chấp: escrow `disputed`, chờ admin.
- Hoàn tiền: theo chính sách huỷ + quyết định tranh chấp.

### Chính sách huỷ mặc định (đề xuất)

| Thời điểm | Passenger | Driver |
|---|---|---|
| Trước khi có driver | Miễn phí | — |
| Driver đã nhận, chưa đến | Miễn phí trong 2 phút đầu; sau đó 10% | Phạt uy tín; hoàn 100% |
| Driver đã đến | 20% hoặc 20.000đ tối thiểu | Phạt nặng; hoàn 100% |
| Trong chuyến | Không huỷ; dùng SOS/hỗ trợ | Không huỷ; báo sự cố |

> Đây là đề xuất; admin có thể cấu hình. Không hiển thị phí huỷ nếu chưa có chính sách chốt.

## 8. Trust & KYC

### Passenger

- OTP phone bắt buộc.
- KYC danh tính (CCCD/selfie) cho:
  - Thanh toán online hạn mức cao.
  - Tài khoản bị báo cáo.
  - Một số chuyến yêu cầu.
- Badge “Đã xác thực” cấp 2/3.

### Driver

- KYC bắt buộc trước khi online:
  - CCCD 2 mặt.
  - GPLX 2 mặt.
  - Đăng ký xe.
  - Bảo hiểm.
  - Selfie.
  - Xe thuộc sở hữu hoặc giấy uỷ quyền (P1).
- Admin duyệt thủ công.
- Hết hạn giấy tờ → tự offline, không nhận chuyến mới.
- Rating thấp hoặc vi phạm → tạm dừng.

### Hiển thị tin cậy

- Driver card: avatar, tên, sao, số chuyến, tỷ lệ hoàn thành, KYC, xe.
- Passenger card (với driver): tên, sao, số chuyến, ghi chú.
- Không hiển thị số điện thoại đầy đủ; dùng che/gọi qua app.

## 9. Safety

- Chia sẻ chuyến qua link/Zalo/SMS.
- SOS gọi 113 + gửi vị trí cho liên hệ khẩn cấp + admin.
- Theo dõi lệch route; cảnh báo nếu dừng lâu.
- Che số điện thoại (masked call) P1; trước đó dùng chat/call qua app.
- Kiểm tra biển số + ảnh xe trước khi lên.
- Report/block user.
- Admin live ops nhận SOS trong 30 giây.

## 10. Feature matrix

| Nhóm | Tính năng | Ưu tiên |
|---|---|---|
| Auth | OTP, refresh, logout, device | P0 |
| Passenger | Map, search, pin | P0 |
| Passenger | Saved places | P1 |
| Passenger | Chọn điểm đón/đến, xem tài xế gần | P0 |
| Passenger | Gửi yêu cầu, tài xế nhận chuyến | P0 |
| Passenger | Thanh toán trực tiếp (chọn phương thức) | P0 |
| Passenger | Đặt giá, mở quote (future offer mode) | P2 |
| Passenger | Đặt lịch | P1 |
| Passenger | Offer list, counter, accept (future offer mode) | P2 |
| Passenger | Tracking, chat, call, share, SOS | P0 |
| Passenger | Payment online/cash, receipt, invoice | P0 |
| Passenger | Rating, report, dispute | P0 |
| Passenger | History, support | P0 |
| Passenger | Promo, referral, wallet top-up | P1 |
| Passenger | Split fare | P2 |
| Passenger | Multi-stop, shared ride, corporate | P2 |
| Driver | Online/offline, nhận chuyến | P0 |
| Driver | Counter/quote (future offer mode) | P2 |
| Driver | Navigate, arrive, start, complete | P0 |
| Driver | Earnings, withdrawal | P0 |
| Driver | KYC/vehicle docs | P0 |
| Driver | Ratings, support, cancellation | P0 |
| Driver | Heatmap, incentives, scheduled | P1 |
| Driver | Insurance/policy display | P1 |
| Admin | Dashboard, live ops, KYC, disputes | P0 |
| Admin | Users, drivers, trips, payments | P0 |
| Admin | Promotions, support, config, audit | P1 |

## 11. Success metrics

- Request → first offer < 45s.
- Request → match < 3 phút.
- Offer acceptance rate.
- Trip completion rate.
- Cancellation rate theo bên.
- Payment success.
- Dispute rate < 1%.
- Rating trung bình.
- Driver online retention.
- Customer support first response.

## 12. Non-goals

- Không bán đồ ăn.
- Không giao hàng.
- Không cho thuê xe tự lái.
- Không bán xe.
- Không membership/gamification.
- Không đặt giá hộ.
- Không hứa “giá rẻ nhất”.
