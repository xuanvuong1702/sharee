# ia.md — Information architecture

## 1. Passenger app

```text
Splash / Bootstrap
└─ Auth
   ├─ Phone → OTP
   ├─ Onboarding (3 bước, P1)
   └─ KYC (khi cần)
└─ Main (tab bar nổi)
   ├─ 01 Trang chủ
   │  ├─ Map
   │  ├─ Search điểm đến
   │  ├─ Saved places
   │  ├─ Recent destinations
   │  ├─ Đặt chuyến
   │  │  ├─ Pickup
   │  │  ├─ Destination
   │  │  ├─ Schedule (now / later)
   │  │  ├─ Vehicle class
   │  │  ├─ Giá: đặt giá / mở quote
   │  │  └─ Notes
   │  ├─ Request active
   │  └─ Promo/ưu đãi (1 dải nhỏ, P1)
   ├─ 02 Chuyến
   │  ├─ Đang diễn ra
   │  ├─ Đã lên lịch
   │  └─ Lịch sử
   │     └─ Chi tiết chuyến
   ├─ 03 Hộp thư
   │  ├─ Tin nhắn
   │  └─ Thông báo
   └─ 04 Tài khoản
      ├─ Hồ sơ & KYC
      ├─ Phương thức thanh toán
      ├─ Ví & giao dịch
      ├─ Địa điểm đã lưu
      ├─ Liên hệ khẩn cấp
      ├─ An toàn
      ├─ Ưu đãi (P1)
      ├─ Hỗ trợ
      ├─ Cài đặt
      └─ Đăng xuất

Overlay flows
├─ Search
├─ Set pickup
├─ Set destination
├─ Offer fare
├─ Matching / Waiting
├─ Offers list
├─ Driver profile
├─ Chat
├─ Tracking
├─ Arrival
├─ In-trip
├─ Completion / Payment
├─ Receipt
├─ Rating
├─ Tip
├─ Cancel flow
├─ Dispute
└─ SOS / Safety
```

## 2. Driver app

```text
Main (role switch)
├─ 01 Nhận chuyến
│  ├─ Online/Offline
│  ├─ Map + radar
│  ├─ Request list
│  ├─ Request detail
│  │  ├─ Accept giá
│  │  └─ Counter / Quote
│  ├─ My offer đang chờ
│  └─ Scheduled requests (P1)
├─ 02 Chuyến của tôi
│  ├─ Active
│  ├─ Completed
│  └─ Cancelled
├─ 03 Thu nhập
│  ├─ Tổng quan
│  ├─ Giao dịch
│  ├─ Rút tiền
│  └─ Thống kê
└─ 04 Tài khoản
   ├─ Hồ sơ & KYC
   ├─ Xe
   ├─ Giấy tờ & hạn
   ├─ Đánh giá
   ├─ An toàn
   ├─ Hỗ trợ
   └─ Cài đặt
```

Driver chi tiết chuyến:

```text
Request detail
├─ Passenger card
├─ Pickup/dropoff + map
├─ Giá passenger đưa
├─ ETA đến pickup
├─ Ghi chú
├─ Accept
├─ Counter
└─ Bỏ qua
```

## 3. Admin web

```text
Login
└─ Dashboard
   ├─ Live ops map
   │  ├─ Trips active
   │  ├─ SOS queue
   │  └─ Driver online
   ├─ KYC
   │  ├─ Queue
   │  ├─ Detail
   │  └─ Documents
   ├─ Trips
   │  ├─ Search
   │  ├─ Detail
   │  └─ Timeline
   ├─ Disputes
   │  ├─ Queue
   │  ├─ Evidence
   │  └─ Resolve
   ├─ Users
   ├─ Drivers
   ├─ Payments / Escrow
   ├─ Promotions
   ├─ Support tickets
   ├─ Config
   └─ Audit log
```

## 4. Nguyên tắc điều hướng

- Passenger không bao giờ phải quay lại Home để xem chuyến đang chạy.
- Có persistent “trip banner” khi đang có chuyến.
- Driver online toggle luôn hiện ở màn Nhận chuyến.
- Không đặt chat trong tab Tài khoản.
- Không có tab “Ưu đãi” riêng; ưu đãi nằm trong Tài khoản/Home strip.
- Admin dùng sidebar cố định + command palette.
- Mọi flow dài có nút back và trạng thái “thoát sẽ mất gì”.

## 5. Deep links

```text
/sharee://trip/{id}
/sharee://offer/{id}
/sharee://driver/{id}
/sharee://invite/{code}
/sharee://support/{ticketId}
/sharee://safety/{tripId}
```

Web:

```text
/trip/{id}
/driver/{id}
/invite/{code}
/support/{ticketId}
```
