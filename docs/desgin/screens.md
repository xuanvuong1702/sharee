# screens.md — Danh mục và đặc tả màn hình

## 0. Phạm vi triển khai v1.4

> Màn đang code: Home → RideBooking (map + chọn điểm) → RideWaiting → DriverMode. Các màn offer/counter bên dưới là **future mode**. Đặc tả hiện tại: `ride-dispatch.md`.


> Kích thước tham chiếu: iPhone 390×844pt, safe area. Android tương đương. Nội dung cuộn có padding đáy cho tab bar.
> Component name → `components.md`; token → `tokens.json`.

## 1. Screen inventory

### Passenger

| ID | Màn | Ưu tiên | Ghi chú |
|---|---|---|---|
| P01 | Home map | P0 | Map-first, search, đặt chuyến |
| P02 | Chọn điểm đón | P0 | GPS/search/pin |
| P03 | Chọn điểm đến | P0 | Search/saved/recent |
| P04 | Cấu hình chuyến | P0 | Giá, loại xe, giờ, ghi chú |
| P05 | Xác nhận gửi yêu cầu | P0 | Bottom sheet tổng kết |
| P06 | Đang tìm tài xế | P0 | Radar, timer, 0 offer |
| P07 | Danh sách offer | P0 | Trái tim sản phẩm |
| P08 | Driver profile | P0 | Trust + chọn |
| P09 | Driver đang đến | P0 | Tracking, liên hệ |
| P10 | Tài xế đã đến | P0 | Biển số, timer |
| P11 | Trong chuyến | P0 | Map, safety |
| P12 | Hoàn tất / thanh toán | P0 | Escrow/cash |
| P13 | Biên nhận | P0 | Ticket |
| P14 | Đánh giá + tip | P0 | Rating |
| P15 | Chuyến của tôi | P0 | Active/scheduled/history |
| P16 | Chi tiết chuyến | P0 | Timeline |
| P17 | Hộp thư | P0 | Chat/notification |
| P18 | Chat | P0 | Masked call |
| P19 | Thông báo | P0 | List/filter |
| P20 | Tài khoản | P0 | Trust center |
| P21 | KYC | P0 | CCCD/selfie |
| P22 | Phương thức thanh toán | P0 | Card/bank/wallet/cash |
| P23 | Ví & giao dịch | P0 | Balance/history |
| P24 | An toàn | P0 | Share/SOS/contacts |
| P25 | Hỗ trợ | P0 | FAQ/chat/ticket |
| P26 | Tranh chấp | P0 | Evidence/status |
| P27 | Địa điểm đã lưu | P1 | Home/work |
| P28 | Đặt lịch | P1 | Date/time |
| P29 | Promo | P1 | List/detail |
| P30 | Referral | P1 | Invite |
| P31 | Cài đặt | P1 | Language, privacy |
| P32 | Onboarding | P1 | 3 slides |
| P33 | Lost item | P1 | Report |
| P34 | Multi-stop | P2 | — |
| P35 | Shared ride | P2 | — |

### Driver

| ID | Màn | Ưu tiên |
|---|---|---|
| D01 | Online/Offline + radar | P0 |
| D02 | Request detail | P0 |
| D03 | Gửi giá / counter | P0 |
| D04 | Offer đang chờ | P0 |
| D05 | Chuyến active | P0 |
| D06 | Đã đến pickup | P0 |
| D07 | Đang chạy | P0 |
| D08 | Hoàn tất | P0 |
| D09 | Thu nhập | P0 |
| D10 | Rút tiền | P0 |
| D11 | Lịch sử chuyến | P0 |
| D12 | KYC onboarding | P0 |
| D13 | Xe & giấy tờ | P0 |
| D14 | Đánh giá | P0 |
| D15 | Hỗ trợ | P0 |
| D16 | Heatmap | P1 |
| D17 | Scheduled | P1 |
| D18 | Incentives | P1 |

### Admin

Xem `admin.md`.

## 2. Golden screens — Passenger

### P01. Home discovery

**Mục tiêu:** tạo cảm giác Green SM, đưa người dùng vào đặt chuyến nhanh.

```text
┌─────────────────────────────┐
│ [Avatar] Xin chào, Minh  🔔 │
│                             │
│  Bạn muốn đi đâu?        🔍 │
│                             │
│  Tài xế gần bạn đang mở     │
│  chuyến · 12 tuyến mới      │
│                             │
│  ┌─────────────┐ ┌────────┐ │
│  │ Đặt chuyến  │ │ Đặt lịch│ │
│  │ 3D car      │ │ 3D clock│ │
│  └─────────────┘ └────────┘ │
│                             │
│  Dịch vụ       Xem tất cả  │
│  [Xe máy] [4 chỗ] [7 chỗ]  │
│  [Sân bay] [Liên tỉnh] ... │
│                             │
│  ┌───────────────────────┐  │
│  │ An tâm mỗi chuyến     │  │
│  │ KYC · Escrow · SOS    │  │
│  └───────────────────────┘  │
│                             │
│  [Tab bar kính]  (Đặt xe)  │
└─────────────────────────────┘
```

- Nền: gradient pastel teal/trắng + texture nhẹ; không full map.
- Search bar nổi, sticky khi cuộn, chuyển glass.
- Dòng gợi ý cá nhân hóa, không bán giá.
- 2 hero card: Đặt chuyến ngay (teal pastel, 3D car), Đặt lịch (vàng pastel, 3D clock).
- Lưới dịch vụ 4 cột: xe máy, 4 chỗ, 7 chỗ, sân bay, liên tỉnh, xe sang, doanh nghiệp, gần đây.
- Trust strip: KYC/escrow/SOS.
- Promo strip nhỏ, không che CTA.
- Active trip banner nếu có.
- Tab bar kính + nút tròn Đặt chuyến.
- States: location denied → CTA bật vị trí; offline banner; loading skeleton cho hero.
- Không dùng banner đồ ăn/quán.

### P02. Map picker / chọn điểm

- Mở từ Home “Đặt chuyến” hoặc search.
- Full map + bottom sheet:
  - Điểm đón (GPS/search).
  - Điểm đến.
  - Bây giờ/Đặt lịch.
  - CTA `Tiếp tục`.
- Saved/recent list.
- Pin kéo thả.
- Location denied fallback.

### P03. Chọn điểm đến

- Search full-screen, keyboard auto.
- Gợi ý: gần đây, đã lưu, địa điểm phổ biến.
- Bản đồ thu nhỏ.
- Không có kết quả → “Không tìm thấy địa điểm. Thử tên khác.”
- Mỗi item có icon 3D/line theo loại.

### P04. Cấu hình chuyến + giá

**Mục tiêu:** người dùng đặt giá hoặc mở quote.

```text
TopBar: Chuyến của bạn
─────────────────────
Route card: Điểm đón → Điểm đến  [Sửa]
Thời gian: Bây giờ / Đặt lịch
Loại xe: [4 chỗ] [7 chỗ] [Xe máy]
─────────────────────
Giá bạn muốn trả
[ 120.000đ ]  [−10k] [+10k]
○ Để tài xế báo giá
Ghi chú: [________________]
─────────────────────
[Thanh toán: Ví Sharee ▾]
[Chính sách huỷ]
[ Tìm tài xế ]
```

- Input giá là trọng tâm, font 28–34, tabular.
- Stepper 10k; long press tăng nhanh.
- “Để tài xế báo giá” là radio/segmented, khi chọn input disabled.
- Hiển thị “Giá cuối do bạn và tài xế thống nhất”.
- CTA disabled nếu chưa có điểm đến/giá hợp lệ (nếu ask).
- Error: giá < 1.000đ hoặc > 10.000.000đ.
- Không tự điền giá.

### P05. Xác nhận gửi yêu cầu

Bottom sheet 60%:

- Route + ETA.
- Giá.
- Phương thức.
- Chính sách huỷ.
- Checkbox “Tôi đồng ý giá và chính sách”.
- CTA `Gửi yêu cầu`.
- Secondary `Sửa`.

### P06. Đang tìm tài xế

- Full map + radar pulse.
- Bottom sheet:
  - “Đang tìm tài xế gần bạn”.
  - Timer 2:00.
  - Số tài xế đã nhận request.
  - `Huỷ yêu cầu`.
- Khi có offer: card “Có 2 tài xế gửi giá” + CTA `Xem giá`.
- 0 offer sau 30s:
  - “Chưa có ai nhận. Bạn có thể tăng giá hoặc mở quote.”
- Hết hạn:
  - “Chưa tìm được tài xế.”
  - `Tăng giá` / `Mở quote` / `Huỷ`.
- Không auto-raise giá.

### P07. Danh sách offer

**Mục tiêu:** chọn tài xế.

```text
┌─────────────────────────────┐
│ ←  Hà Nội → Hải Phòng       │
│ Giá bạn đưa: 120.000đ       │
│ 2:14 còn lại  [Làm mới]     │
│ [Giá thấp] [Đến sớm] [Uy tín]│
│                             │
│ ┌─────────────────────────┐ │
│ │ 120.000đ   Đến sau 4'   │ │
│ │ Minh · 4.9★ · 128 chuyến│ │
│ │ KYC ✓ · Toyota Vios     │ │
│ │ [Chọn tài xế]           │ │
│ └─────────────────────────┘ │
│ ┌─────────────────────────┐ │
│ │ 140.000đ  +20.000đ      │ │
│ │ Hằng · 4.8★ · 96 chuyến │ │
│ │ Đề nghị giá             │ │
│ └─────────────────────────┘ │
└─────────────────────────────┘
```

- Header sticky: route + giá passenger + countdown.
- Sort chips.
- Offer card:
  - Giá lớn.
  - ETA.
  - Driver name, rating, trips, KYC.
  - Vehicle.
  - Chênh lệch nếu counter (amber).
  - Nút chọn.
- Tap card → P08.
- Empty: “Chưa có tài xế gửi giá. Thử tăng giá hoặc mở quote.”
- Expired: card mờ + label.
- Pull-to-refresh; live update qua SignalR.

### P08. Driver profile

Bottom sheet 80%:

- Avatar, tên, hạng uy tín.
- Sao, số chuyến, tỷ lệ hoàn thành, năm tham gia.
- KYC badge.
- Xe: ảnh, hãng, màu, biển số (che 1 phần? Hiển thị đủ khi đã chọn).
- Giá + ETA.
- Đánh giá gần đây (3).
- CTA `Chốt chuyến`.
- Secondary `Nhắn tin` (template an toàn trước match).
- Report.

### P09–P10. Driver đang đến / đã đến

- Full map, route driver → pickup.
- Bottom sheet:
  - Driver card, ETA, biển số.
  - `Nhắn tin`, `Gọi`.
  - “Tài xế đã đến” state: nút `Tôi đã lên xe` (optional), timer chờ.
- Safety row: `Chia sẻ chuyến`, `SOS`.
- States: driver delayed >5 phút → banner + huỷ miễn phí.
- Driver cancelled → “Tài xế đã huỷ. Tìm tài xế khác?”.

### P11. Trong chuyến

- Map full; route line.
- Bottom sheet:
  - ETA + remaining distance.
  - Driver card.
  - Actions: Chat, Call, Share, SOS.
  - `Kết thúc` chỉ driver (passenger không thấy).
- Nếu passenger: “Chuyến đang diễn ra” + support.
- Nếu lệch route: amber banner.

### P12–P13. Hoàn tất / thanh toán / biên nhận

- Success header: “Chuyến đã hoàn tất”.
- Fare breakdown:
  - Cước.
  - Phụ phí.
  - Phí nền tảng.
  - Tip.
  - Tổng.
- Payment:
  - Online: “Đã thanh toán bằng Ví Sharee” / “Đang giải ngân cho tài xế”.
  - Cash: “Bạn đã trả tiền mặt?” → `Xác nhận`.
- CTA `Đánh giá tài xế`; secondary `Biên nhận`.
- Receipt ticket:
  - Mã chuyến, route, thời gian, giá, phương thức.
  - QR (token ký).
  - Nút chia sẻ/tải.

### P14. Đánh giá + tip

- 5 sao lớn.
- Tag chips.
- Comment.
- Tip chips 10k/20k/50k/khác.
- `Gửi đánh giá`.
- Skip.

### P15–P16. Chuyến của tôi / chi tiết

- Tabs: Đang chạy | Đã lịch | Lịch sử.
- Card: route, ngày, giá, driver, status.
- Active trip banner.
- Detail: timeline, payment, receipt, support, report.
- Empty state.

### P17–P19. Hộp thư / chat / thông báo

- Chat list with driver/avatar, last message, unread.
- Chat:
  - Template messages before match.
  - Text after match.
  - Masked call button.
  - Safety banner.
- Notifications filter: Tất cả | Chuyến | Khuyến mãi.
- Mark all read.

### P20–P26. Account / KYC / payment / safety / support / dispute

- Profile: trust center, KYC status, stats, menu groups.
- KYC: CCCD/selfie upload, status.
- Payment methods: card/bank/wallet/cash, default, masked numbers.
- Wallet: balance, top-up, transactions.
- Safety: share trip default, emergency contacts, SOS instructions.
- Support: FAQ, chat, ticket.
- Dispute: type, description, evidence, status.

## 3. Golden screens — Driver

### D01. Online + radar

```text
Top: Chế độ tài xế [Online ●]
Map + radar + request pins
Bottom sheet:
  “3 chuyến quanh bạn”
  Request cards: pickup distance, giá, dropoff
  [Bật online] khi offline
```

- Offline: map mờ, CTA bật online, nhắc KYC.
- KYC chưa duyệt: chặn, CTA `Hoàn tất xác thực`.
- Filter chips.

### D02–D03. Request detail / offer

- Passenger rating.
- Pickup/dropoff map.
- Giá passenger.
- ETA đến pickup.
- Note.
- `Nhận giá`, `Trả giá`, `Bỏ qua`.
- Counter input with difference.
- Countdown.
- Không hiển thị SĐT đầy đủ.

### D05–D08. Active trip

- Navigate.
- Arrived → timer.
- Start → in progress.
- Complete → fare summary.
- Cash collect step.
- Safety.

### D09–D10. Earnings / withdraw

- Today/week/month.
- Balance.
- Transactions.
- Withdraw to bank.
- Fee.
- Pending.

### D12–D13. KYC / vehicle

- Progress checklist.
- Upload each doc.
- Status pending/rejected.
- Expiry.
- Vehicle list.

## 4. Admin

Xem `admin.md`. Key screens:

- A01 Dashboard.
- A02 Live ops map.
- A03 SOS detail.
- A04 KYC queue/detail.
- A05 Trips list/detail.
- A06 Disputes queue/detail.
- A07 Users/drivers.
- A08 Payments/escrow.
- A09 Promotions.
- A10 Config.
- A11 Audit.

## 5. Screen state matrix

| Screen | Loading | Empty | Error | Offline |
|---|---|---|---|---|
| Home | skeleton sheet | location prompt | retry | banner |
| Offers | skeleton cards | no offer CTA | retry | cache + banner |
| Trips | skeleton | empty CTA | retry | cache |
| Chat | skeleton | “Bắt đầu trò chuyện” | retry | queue messages |
| Driver radar | skeleton | “Chưa có chuyến” | retry | offline |
| Earnings | skeleton | “Chưa có thu nhập” | retry | cache |
| Admin queues | skeleton rows | empty state | error | N/A |

## 6. Responsive

- 360pt: giảm padding 12, offer card 1 cột, ẩn 1 số metadata.
- 390–430: chuẩn.
- Tablet/web: passenger app max-width 480, admin full.
- Driver app: map + list split ở tablet (P1).

## 7. Motion per screen

- Home sheet: 280ms.
- Offer mới: fade/slide 200ms + badge.
- Accept: card scale 0.98 → success tick.
- Map camera: 500ms ease.
- Receipt: fade + ticket slide.
- Success: subtle check, không confetti quá 600ms.
