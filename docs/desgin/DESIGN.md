# DESIGN.md — Sharee: chợ chuyến đi thương lượng

## 0. Phạm vi triển khai v1.4

> **Luồng đang code:** `ride-dispatch.md`. App không nhập/đặt giá; passenger chọn điểm đón/đến + phương thức thanh toán, tài xế online nhận chuyến, giá thỏa thuận trực tiếp. Các mục offer/counter/escrow giá bên dưới là **future mode**, chưa bật.


> **v1.4** — source of truth, Green SM-inspired + direct dispatch cho thiết kế lại toàn bộ app.
> Đọc `README.md` trước. Bản Green SM cũ nằm ở `_reference-green-sm/`, chỉ để tham khảo.

## 1. Tầm nhìn

**Sharee là nơi hai người tự thỏa thuận một chuyến đi, còn nền tảng lo phần an toàn, minh bạch và thanh toán.**

App không phải một hãng xe. App không áp giá. App không giấu tài xế sau thuật toán. App tạo một **chợ** nơi người đi và tài xế gặp nhau, thấy giá, thấy uy tín, thấy chuyến, rồi tự quyết định.

### Một câu định vị

> **Trả giá của bạn. Chọn tài xế của bạn. Đi theo cách của bạn.**

### Giá trị cốt lõi

| Giá trị | Nghĩa là |
|---|---|
| **Tự do giá** | Người đi đặt giá; tài xế nhận, trả giá hoặc báo giá. Không surge, không giá ảo. |
| **Tin cậy** | KYC tài xế, đánh giá thật, lịch sử chuyến, escrow, tranh chấp có bằng chứng. |
| **Rõ ràng** | Giá chốt, phí, toll, huỷ, hoàn tiền đều hiển thị trước khi xác nhận. |
| **An toàn** | Theo dõi trực tiếp, chia sẻ chuyến, SOS, che số điện thoại. |
| **Công bằng** | Tài xế thấy yêu cầu thật; người đi thấy lời cháo thật; không bóp giá bằng thuật toán. |

## 2. Actor

| Actor | Mục tiêu chính | Không được làm |
|---|---|---|
| **Passenger** | Tìm chuyến đúng giá, đúng giờ, an toàn | Đặt giá thấp hơn 0; spam nhiều request; quấy rối |
| **Driver** | Nhận chuyến có lời, chủ động giá, kiếm thu nhập | Nhận chuyến khi chưa KYC; huỷ vô lý; đòi thêm tiền ngoài app |
| **Admin/Ops** | Giữ chợ an toàn, xử lý KYC/tranh chấp/SOS | Tự đặt giá thay người dùng; xem dữ liệu nhạy cảm không lý do |
| **Support** | Hỗ trợ, hoàn tiền, tra cứu | Can thiệp giá đã chốt nếu không có tranh chấp |

## 3. Mục tiêu và phi mục tiêu

### Mục tiêu

- Đặt chuyến từ mở app đến gửi yêu cầu **≤ 60 giây**.
- Tài xế hiểu yêu cầu và gửi giá **≤ 20 giây**.
- Người đi chốt tài xế **≤ 3 chạm** từ danh sách offer.
- Không có màn hình nào không có loading/rỗng/lỗi.
- Tất cả giao dịch tiền có biên nhận và trạng thái.
- Hỗ trợ tiếng Việt có dấu, màn 360pt, một tay.

### Phi mục tiêu (không làm)

- Đồ ăn, giao hàng, mua sắm, phim, siêu app.
- Membership, nhiệm vụ, gamification môi trường.
- App tự đặt giá hoặc surge.
- Đấu giá kín nhiều vòng phức tạp.
- Mạng xã hội, feed tin tức.
- Ví crypto.

## 4. Mô hình giá — trái tim sản phẩm

### 4.1 Nguyên tắc

1. **Không có giá do app quyết định.** Không có “giá cước chuẩn” bắt buộc.
2. Passenger có thể chọn:
   - **Đặt giá**: nhập số tiền mình muốn trả.
   - **Để tài xế báo giá**: không nhập giá, tài xế gửi offer.
3. Driver có thể:
   - **Nhận ngay** mức giá passenger đưa.
   - **Trả giá** (counter-offer) cao hơn/thấp hơn.
   - **Gửi báo giá** nếu passenger mở.
4. **Giá chốt khi passenger chọn offer.** Từ lúc đó giá bị khóa, không đổi trừ khi hai bên đồng ý phụ phí.
5. **Không phí ẩn.** Giá chốt phải bao gồm:
   - Cước đã thỏa thuận.
   - Phí nền tảng (nếu bật, hiển thị riêng).
   - Toll/parking chỉ được thêm nếu khai báo trước và passenger xác nhận.
6. **Không có surge.** Nếu cầu cao, tài xế tự trả giá cao hơn; app không nhân giá.
7. **Giá tham khảo** (nếu có) chỉ là dữ liệu lịch sử ẩn sau “Tham khảo”, không bắt buộc, không tự điền.
8. **Tiền tệ VND**, hiển thị `120.000đ`.

### 4.2 Các loại offer

| Loại | Ai tạo | Khi nào | Hiệu lực |
|---|---|---|---|
| `ask` | Passenger | Nhập giá trước | 2 phút, có thể gia hạn 1 lần |
| `open` | Passenger | Không nhập giá | 3 phút |
| `accept` | Driver | Nhận giá ask | Khóa ngay |
| `counter` | Driver | Đề xuất giá khác | 90 giây |
| `quote` | Driver | Báo giá cho open | 90 giây |

### 4.3 Luồng giá tối thiểu

```text
Passenger tạo request
  → chọn "Đặt giá" hoặc "Để tài xế báo giá"
  → hệ thống gửi đến tài xế gần
  → tài xế accept / counter / quote
  → passenger xem offer list
  → chọn 1 offer
  → khóa giá + escrow (nếu online) + tạo Trip
```

## 5. Nguyên tắc thiết kế

### P1. Map là bối cảnh, offer là nhân vật chính

Home và tracking dùng bản đồ làm nền. Nhưng khi có offer, **offer list/sheet nổi lên trên map** và là nơi mắt nhìn đầu tiên. Không để banner khuyến mãi che offer.

### P2. Giá phải luôn nhìn thấy cùng ngữ cảnh

Mỗi offer phải có:

- Giá.
- ETA đến điểm đón.
- Thời gian chuyến.
- Tài xế + xe.
- Uy tín/KYC.
- Chênh lệch so với giá passenger đưa (nếu counter).

Không có offer chỉ có mỗi con số.

### P3. Một màn hình, một quyết định

- Home: đặt chuyến.
- Offers: chọn tài xế.
- Tracking: theo dõi/an toàn.
- Completion: thanh toán/đánh giá.
Không trộn ba quyết định vào một màn.

### P4. Tin cậy hiển thị đúng lúc

- Trước khi chọn: KYC, sao, số chuyến, tỷ lệ hoàn thành.
- Trước khi trả tiền: escrow, phương thức, huỷ/hoàn.
- Trong chuyến: chia sẻ, SOS, che số.
- Sau chuyến: biên nhận, tranh chấp.

### P5. Nói bằng tiền, không nói bằng thuật ngữ

- “Tài xế đề nghị thêm 20.000đ” thay vì “counter-offer adjustment”.
- “Tiền đang được giữ” thay vì “escrow authorized”.
- “Chuyến đã hủy” thay vì “trip state cancelled_by_driver”.

### P6. Không bao giờ để người dùng bối rối vì trạng thái

Mọi trạng thái có:

- Tên trạng thái.
- Việc đang xảy ra.
- Việc người dùng cần làm.
- Thời gian chờ/CTA.

### P7. Một tay, ngoài trời, mạng yếu

- CTA trong 1/3 dưới màn hình.
- Bottom sheet thay vì modal nhỏ.
- Text ≥ 14pt; touch ≥ 44pt.
- Offline banner + cache; không mất request đã gửi.

### P8. Mềm mại có kiểm soát

- Dùng teal pastel, card bo lớn, 3D icon và bóng mềm như Green SM.
- Gradient chỉ để làm nền/hero, không thay nội dung.
- Không dùng logo/mascot/3D asset của Green SM; asset phải riêng.
- Không biến mọi thứ thành pastel: CTA/giá/trạng thái vẫn phải tương phản rõ.

## 6. Hướng thị giác

### Từ khoá

> **Green SM pastel · mềm · tin cậy · đô thị · thân thiện**

### Palette

| Vai trò | Token | Hex | Dùng |
|---|---|---|---|
| Primary vivid | `color.brand.primaryVivid` | `#2CCBD3` | Active, icon, indicator |
| Primary surface | `color.brand.primary` | `#5EC9D1` | Nền tint, illustration, không dùng chữ trắng nhỏ |
| Primary deep | `color.brand.primaryDeep` | `#0E7F88` | Nút chính, chữ trên nền sáng, link |
| Primary text | `color.brand.primaryText` | `#1A8F98` | Link/giá trên nền trắng |
| Primary tint | `color.brand.primaryTint` | `#E6F7F8` | Card, selected, tonal button |
| Ink | `color.neutral.ink` | `#1E2528` | Heading |
| Ink strong | `color.neutral.ink900` | `#0B1B22` | Nền tối, tab bar |
| Background | `color.neutral.bg` | `#F4F6F8` | Nền chính |
| Surface | `color.neutral.surface` | `#FFFFFF` | Card/input |
| Line | `color.neutral.line` | `#E3E7EA` | Viền |
| Muted | `color.neutral.muted` | `#6B7479` | Metadata |
| Promo | `color.semantic.promoBg` | `#FBEFB0` | Badge/banner ưu đãi |
| Safety | `color.semantic.safety` | `#C2410C` | SOS/an toàn |
| Danger | `color.semantic.danger` | `#D64545` | Huỷ, lỗi, xóa |

**Quy tắc tương phản:** chữ trắng chỉ dùng trên `primaryDeep`/`ink900`; không dùng chữ trắng nhỏ trên `primary`/`primaryVivid`.

### Typography

- **Be Vietnam Pro** — hỗ trợ tiếng Việt; thay cho Google Sans.
- Display 34/38, H1 28/34, H2 22/28, body 15/22, caption 12/16.
- Số tiền dùng tabular figures.
- Không dùng Roboto mặc định.

### Hình ảnh & 3D

- Ảnh thật: đường phố Việt Nam, xe, tài xế, điểm đón.
- 3D icon pastel cho dịch vụ chính; line icon cho cài đặt.
- 3D asset phải là bộ riêng hoặc license mở (Fluent Emoji 3D MIT), không lấy của Green SM.
- Nền 3D: gradient teal nhạt, cùng góc nhìn/ánh sáng.

### Icon

- 3D: dịch vụ chính (Đặt xe, Đặt lịch, An toàn).
- Line 24pt: cài đặt/danh sách.
- Không trộn 3D + line trong cùng nhóm.
- Không dùng emoji thay icon chức năng.

### Motion

- Base 220ms, tab 250ms spring, sheet 280ms, success 400ms, map 500ms.
- Floating tab bar active indicator trượt.
- Search glass khi cuộn 180ms.
- 3D icon float ±2px / 3.2s (chỉ decorative).
- Offer mới fade/slide + badge.
- Tôn trọng Reduce Motion.

Chi tiết: `motion.md`.

## 7. Navigation

### Passenger

Tab bar nổi 4 tab, chỉ icon + label khi accessibility:

1. **Trang chủ** — discovery: search, dịch vụ, tuyến gần đây; map nằm trong flow đặt chuyến.
2. **Chuyến** — đang chạy/lịch sử.
3. **Hộp thư** — chat, thông báo, offer.
4. **Tài khoản** — KYC, ví, phương thức, an toàn, hỗ trợ.

Nút tròn **“Đặt chuyến”** tách khỏi tab bar (vị trí giống Trophy của Green SM, nhưng là CTA).

### Driver

Cùng app, chuyển vai trò:

1. **Nhận chuyến** — online/offline, radar request.
2. **Chuyến của tôi** — active/history.
3. **Thu nhập** — ví, rút tiền, thống kê.
4. **Tài khoản** — KYC, xe, đánh giá, hỗ trợ.

### Admin

Web sidebar:

- Tổng quan
- Live ops
- KYC
- Chuyến
- Tranh chấp
- Người dùng
- Tài xế
- Thanh toán/escrow
- Khuyến mãi
- Hỗ trợ
- Cấu hình
- Audit

## 8. Luật cứng

1. Chỉ dùng token trong `tokens.json`; không hardcode hex/px/ms.
2. Mỗi màn/vùng cuộn có tối đa **1 primary CTA**.
3. Grid 4pt; lề 16; khe card 12; section cách 24.
4. Touch ≥ 44×44; khoảng cách touch ≥ 8.
5. Mọi input có label ngoài, helper/error, trạng thái focus/disabled.
6. Mọi list có loading/rỗng/lỗi/offline.
7. Không dùng màu làm tín hiệu duy nhất; thêm icon/chữ.
8. Không hiển thị đầy đủ số điện thoại/CCCD/thẻ.
9. Không chép asset/logo/mascot/illustration của app khác.
10. Không tự thêm phí hoặc đổi giá sau khi chốt.
11. Không cho driver nhận chuyến khi KYC chưa duyệt.
12. Không cho passenger tạo chuyến khi chưa xác thực số điện thoại.
13. Không cho chat trước khi match ngoài template an toàn.
14. Không hiển thị giá “từ ...” như thể là giá cố định.
15. Không dùng chữ nhỏ hơn 12pt.

## 9. Ưu tiên khi xung đột

1. An toàn/pháp lý.
2. Accessibility.
3. Quy tắc giá minh bạch.
4. Trạng thái rõ ràng.
5. Token/component.
6. Thẩm mỹ.

## 10. Checklist nghiệm thu

- [ ] Giá cuối do người dùng chốt, app không tự đặt.
- [ ] Offer hiển thị đủ giá, ETA, tài xế, xe, uy tín.
- [ ] Có trạng thái loading/rỗng/lỗi/offline.
- [ ] Có countdown/hết hạn cho offer.
- [ ] Có xác nhận trước khi huỷ/thanh toán.
- [ ] Escrow/phương thức tiền hiển thị trước khi chốt.
- [ ] KYC/uy tín hiển thị trước khi chọn tài xế.
- [ ] Một primary CTA.
- [ ] Contrast ≥ 4.5:1; touch ≥ 44.
- [ ] Dynamic Type 130% không vỡ.
- [ ] Không hardcode token.
- [ ] Không có asset của app khác.
- [ ] Có microcopy cho trạng thái chờ/offer hết hạn/tài xế huỷ.
- [ ] Có biên nhận sau chuyến.
- [ ] Có đường vào tranh chấp/hỗ trợ.

## 11. Quyết định mặc định (có thể đổi sau)

- Visual + motion: Green SM pastel/teal/3D, asset riêng.
- Primary CTA dùng teal đậm `#0E7F88`; `#5EC9D1` chỉ làm nền/tint/active.
- Offer/accent dùng amber; trust dùng mint.
- Font: Be Vietnam Pro.
- Platform fee MVP: **0%**; nếu bật, hiển thị riêng.
- Offer validity: ask 2 phút; open 3 phút; counter/quote 90 giây.
- Tối đa 5 offer active/tài xế; tối đa 20 offer/request.
- Cash và online đều hỗ trợ; online dùng escrow.
- Không có đấu giá auto; người dùng chốt thủ công.
- Không có multi-stop trong MVP; P1.
- Không có shared ride trong MVP; P2.
- Dark mode P1.
- Admin và app dùng cùng token, khác density.

Chi tiết mở: xem `decisions.md`.
