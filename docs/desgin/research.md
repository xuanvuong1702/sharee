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

## 4. Quyết định hướng đi (cập nhật 2026-11-19)

Chủ dự án chọn **dùng ngôn ngữ thị giác và animation của Green SM** cho Sharee.

Điều đó có nghĩa:

- **Adopt**: teal pastel, card mềm, 3D icon, floating glass tab bar, search nổi, bottom sheet, nhịp animation nhẹ.
- **Không adopt**: logo, mascot, illustration, screenshot, tên dịch vụ, giá cố định, super-app, trophy/gamification.
- **Giữ nguyên**: mô hình thương lượng giá, IA ride-hailing, trust/payment/safety.

> Công thức: **Visual + motion Green SM × mô hình giá inDrive × map Bolt × trust BlaBlaCar × admin Linear.**

## 5. Benchmark đúng cho Sharee

| App | Học gì | Không học |
|---|---|---|
| **Green SM** | Teal pastel, card mềm, 3D icon, floating tab bar, search nổi, animation nhẹ | Logo/mascot/asset, super-app, giá cố định, trophy |
| **inDrive** | Mô hình offer/counter, hiển thị giá hai chiều, chọn tài xế | UI quá dày, màu vàng/đen |
| **BlaBlaCar** | Trust card, route, ghế, huỷ, review | Giá cố định |
| **Bolt / Grab** | Map-first, bottom sheet, live tracking, driver card | Super-app, voucher |
| **Uber** | Safety, share trip, receipt, masked call | Surge |
| **Airbnb** | Ảnh thật, review, trust | Card quá lớn |
| **Revolut / Wise** | Escrow, payment method, receipt | Fintech lạnh |
| **Linear** | Admin command palette, density, drawer | Ít màu |
| **Trainline / Omio** | Ticket, route timeline, QR | Chỉ dành cho tàu/xe khách |

### Kết luận benchmark

> **Green SM cho look & motion + inDrive cho giá + Bolt cho map + BlaBlaCar cho trust + Linear cho admin.**

## 6. Điều nên học từ Green SM

### Học

- Teal pastel và trạng thái active phát sáng.
- Card dịch vụ chính to, rõ, ít chữ; 3D icon.
- Floating glass tab bar + nút tròn tách riêng.
- Search nổi, sticky khi cuộn.
- Bottom sheet thay modal.
- Empty state có minh hoạ + CTA.
- Filter chips ngang.
- Form có nhãn ngoài, helper, sticky CTA.
- Che thông tin nhạy cảm.
- Một kiểu back, một kiểu tiền, một kiểu ngày.
- Animation mềm 150–300ms, tab indicator spring.
- Accessibility được đặt trước thẩm mỹ.

### Không copy

- Logo, mascot, bộ 3D, ảnh banner, screenshot.
- Super-app services (đồ ăn, giao hàng, thuê xe, mua xe).
- Giá cố định do app đặt.
- Trophy/Green Race/gamification.
- Hồ sơ dài 20 mục.
- Home ưu tiên đồ ăn/quán.
- Mật độ banner/khuyến mãi dày.

## 7. Khác biệt cốt lõi của Sharee

| Green SM | Sharee |
|---|---|
| App đặt giá | Người dùng đặt giá |
| Tài xế nhận cuốc | Tài xế trả giá |
| Một lựa chọn | Nhiều offer để chọn |
| Surge ngầm | Không surge |
| Super-app | Chỉ chuyến đi |
| Teal/3D pastel | **Cùng ngôn ngữ thị giác, asset riêng** |
| Một chiều | Thương lượng hai chiều |

## 8. Nguyên tắc research

- Không copy asset, logo, mascot, illustration, screenshot.
- Được copy **pattern thị giác/animation** đã được chứng minh.
- Mọi pattern phải phục vụ **chọn giá/chọn tài xế**, không chỉ để giống app.
- Nếu pattern chỉ để “trông giống app xịn”, bỏ.
