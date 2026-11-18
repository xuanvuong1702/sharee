# research.md — Phân tích bản sơ bộ và benchmark

> Nguồn sơ bộ: 18 ảnh iPhone + 4 video của **Green SM v5.13.0** trong `screenshot/`.  
> Mục đích: rút ra bài học về hệ thống, không sao chép thương hiệu/asset.

## 1. Bản sơ bộ đã làm đúng gì

- Có hệ thống token thay vì màu tuỳ hứng.
- Có phân cấp màn hình, component, trạng thái, accessibility.
- Có quy tắc một CTA, touch 44, contrast, Dynamic Type.
- Có ý thức không chép logo/mascot.
- Có mô tả golden screens và empty states.

## 2. Bản sơ bộ chưa phù hợp với sản phẩm mới

| Vấn đề | Vì sao không dùng |
|---|---|
| Mô hình super-app (xe, đồ ăn, giao hàng, thuê xe, mua xe) | Sharee chỉ làm chuyến đi; thêm dịch vụ làm loãng offer |
| Giá cố định do app | Trái với mô hình thương lượng |
| Home nhiều banner, voucher, quán ăn | Che mất hành động đặt chuyến |
| Tab bar 4 icon + Trophy | Không có gamification; cần tab Chuyến/Thu nhập cho tài xế |
| Teal + 3D mascot | Bản sắc riêng của Green SM; không chép |
| Hồ sơ quá nhiều mục | Sharee cần KYC, xe, ví, an toàn, hỗ trợ |
| Không có màn thương lượng giá | Đây là màn quan trọng nhất |
| Không có vai trò tài xế | App gọi xe phải có driver mode |
| Không có live ops/SOS | Thiếu vận hành thực tế |
| Không có state machine offer/trip/payment | Không thể code đúng |

## 3. Ảnh tham chiếu — thống kê

| # | Màn | Bài học |
|---|---|---|
| 1 | Home | Search nổi, 2 dịch vụ chính, lưới phụ, banner |
| 2 | Home cuộn | Search sticky, nội dung trượt dưới |
| 3 | Home cuộn thêm | Card lớn, carousel |
| 4 | Hoạt động rỗng | Empty state + CTA rõ |
| 5-6 | Thông báo | Filter chips, item có ảnh |
| 7 | Hồ sơ | Hero gradient, stats, nhóm tác vụ |
| 8 | Hồ sơ cuộn | Nhiều nhóm, CTA |
| 9-10 | Cài đặt | List row, nhóm rõ, destructive |
| 11-12 | Cập nhật tài khoản | Form, select, sticky CTA, trạng thái disabled |
| 13 | Thanh toán | Nhóm phương thức, che số, nạp tiền |
| 14 | Hỗ trợ | Chat, safety card, nhóm hỗ trợ |
| 15 | Ưu đãi rỗng | Empty state |
| 16 | Safety Centre | Danh sách tính năng an toàn |
| 17 | Hội viên | Sticky CTA, minh bạch giá |
| 18 | Đóng góp bản đồ | Hero, list, empty |

**Kết luận:** đây là UI của một super-app tối ưu cho khám phá dịch vụ và khuyến mãi. Sharee cần UI tối ưu cho **ra quyết định giá và chọn tài xế**, nên cấu trúc phải khác.

## 4. Benchmark đúng cho Sharee

| App | Học gì | Không học |
|---|---|---|
| **inDrive** | Mô hình offer/counter, hiển thị giá hai chiều, chọn tài xế | UI quá dày, màu vàng/đen |
| **BlaBlaCar** | Trust card, route, ghế, huỷ, review | Giá cố định |
| **Bolt / Grab** | Map-first, bottom sheet, live tracking, driver card | Super-app, voucher |
| **Uber** | Safety, share trip, receipt, masked call | Surge |
| **Airbnb** | Ảnh thật, review, trust | Card quá lớn |
| **Revolut / Wise** | Escrow, payment method, receipt | Fintech lạnh |
| **Linear** | Admin command palette, density, drawer | Ít màu |
| **Trainline / Omio** | Ticket, route timeline, QR | Chỉ dành cho tàu/xe khách |

### Kết luận benchmark

> **inDrive cho mô hình giá + Bolt cho map/tracking + BlaBlaCar cho trust + Linear cho admin.**

## 5. Điều nên học từ Green SM

### Học

- Search nổi trên map và sticky khi cuộn.
- Card dịch vụ chính to, rõ, ít chữ.
- Bottom sheet thay modal.
- Empty state có minh hoạ + CTA.
- Filter chips ngang.
- Form có nhãn ngoài, helper, sticky CTA.
- Che thông tin nhạy cảm.
- Một kiểu back, một kiểu tiền, một kiểu ngày.
- Accessibility được đặt trước thẩm mỹ.

### Không học

- Mật độ banner/khuyến mãi.
- Màu teal và 3D icon của Green SM.
- Super-app services.
- Trophy/gamification.
- Hồ sơ dài 20 mục.
- Tab bar 5 thành phần.
- Home ưu tiên đồ ăn/quán.

## 6. Khác biệt cốt lõi của Sharee

| Green SM | Sharee |
|---|---|
| App đặt giá | Người dùng đặt giá |
| Tài xế nhận cuốc | Tài xế trả giá |
| Một lựa chọn | Nhiều offer để chọn |
| Surge ngầm | Không surge |
| Super-app | Chỉ chuyến đi |
| Teal/3D | Ink/cobalt/amber, ảnh thật |
| Một chiều | Thương lượng hai chiều |

## 7. Nguyên tắc research

- Không copy asset, logo, mascot, illustration, screenshot.
- Không copy nguyên layout Green SM; chỉ copy pattern đã được chứng minh.
- Mọi pattern phải chứng minh được lợi ích cho **chọn giá/chọn tài xế**.
- Nếu pattern chỉ để “trông giống app xịn”, bỏ.
