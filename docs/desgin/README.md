# Sharee Design Docs

> **Trạng thái:** v1.4 — Green SM visual + dispatch trực tiếp cho mô hình **chợ chuyến đi thương lượng giá**.
> **Phạm vi:** tài liệu thiết kế, chưa phải code. Mọi quyết định triển khai phải bám tài liệu này.
> **Ngôn ngữ:** tiếng Việt có dấu. Code/API dùng tiếng Anh.

## 1. Sản phẩm là gì

**Sharee** là ứng dụng gọi xe kết nối passenger với tài xế đang online:

- Người đi chọn điểm đón/trả, loại xe và **phương thức thanh toán**; app không nhập/đặt giá.
- Tài xế online gần đó nhận thông báo; tài xế đầu tiên nhận chuyến sẽ đi đến/đón/hoàn tất.
- Giá cước do passenger và tài xế **tự thỏa thuận trực tiếp**; app không can thiệp.
- App chỉ hỗ trợ ghi nhận phương thức thanh toán (tiền mặt/chuyển khoản/ví).
- **v1.4** dùng luồng dispatch trực tiếp; offer/counter trong tài liệu là **future mode**, chưa bật.

Đây không phải super-app đồ ăn/giao hàng. Không có Green SM membership, nhiệm vụ, voucher dày đặc.

> **Nguồn hiện tại:** `ride-dispatch.md` cho luồng đang code. Các mục offer/counter trong `product.md`, `flows.md`, `screens.md` chỉ dùng khi bật future mode.

## 2. Đọc theo thứ tự

| File | Nội dung | Khi nào đọc |
|---|---|---|
| `README.md` | Mục lục, trạng thái, cách dùng | Đầu tiên |
| `ride-dispatch.md` | **Luồng đặt xe trực tiếp đang triển khai (v1.4)** | Khi code flow hiện tại |
| `DESIGN.md` | Triết lý, nguyên tắc, luật cứng, checklist | Trước khi thiết kế/kỷ luật |
| `product.md` | Mô hình thương lượng, actor, business rules, feature matrix | Trước khi vẽ luồng |
| `research.md` | Phân tích 18 ảnh Green SM, benchmark, điều nên/chưa nên học | Trước khi chọn phong cách |
| `motion.md` | Animation Green SM + đặc tả chuyển động | Khi làm animation |
| `video-analysis.md` | Phân tích frame 4 video Green SM | Khi cần bám video |
| `ia.md` | Sitemap hành khách, tài xế, admin | Trước khi dựng màn |
| `flows.md` | Luồng đầu-cuối và edge cases | Trước khi dựng flow |
| `screens.md` | Danh mục màn hình + đặc tả golden screens | Khi dựng màn |
| `components.md` | Anatomy, variants, states của component | Khi dựng UI |
| `content-and-states.md` | Microcopy, trạng thái, accessibility, anti-pattern | Khi viết chữ/state |
| `tokens.json` | Token màu, chữ, spacing, radius, motion | Mọi lần dựng UI |
| `admin.md` | Thiết kế admin web | Khi dựng admin |
| `implementation-gap.md` | Khoảng cách với codebase hiện tại, thứ tự triển khai | Trước khi code |
| `decisions.md` | Decision log, giả định, câu còn mở | Khi có xung đột |

Bản Green SM sơ bộ được giữ tại `_reference-green-sm/` để tra cứu, **không dùng làm source of truth**.

## 3. Nguyên tắc bất biến

1. **Giá do người dùng quyết định.** App chỉ hiển thị, ghi nhận, đối soát; không tự áp giá.
2. **Map-first, one-hand-first.** Mọi hành động chính nằm trong tầm ngón tay cái.
3. **Offer là trung tâm.** Màn hình thương lượng phải rõ hơn mọi banner/khuyến mãi.
4. **Trust đi cùng tiền.** KYC, escrow, đánh giá, uy tín và biên nhận xuất hiện đúng lúc.
5. **Không có màn hình trống câm.** Luôn có trạng thái loading/rỗng/lỗi/offline.
6. **Một CTA chính.** Không cạnh tranh bằng hai nút primary.
7. **Không chép asset/logo/mascot của Green SM hay bất kỳ app nào.**
8. **Mọi trạng thái là một phần của thiết kế**, không phải phần code bổ sung sau.

## 4. Cách AI làm việc với bộ tài liệu

Trước khi tạo/sửa màn hình:

1. Đọc `DESIGN.md`, `product.md`, `ia.md`, `flows.md`.
2. Liệt kê 3–5 ràng buộc áp dụng cho màn đó.
3. Dùng token trong `tokens.json`, component trong `components.md`.
4. Tự chấm checklist `DESIGN.md §10`.
5. Nếu phải lệch tài liệu, ghi vào `decisions.md` và nêu lý do; không lặng lẽ làm khác.
6. Không thêm tính năng ngoài phạm vi nếu chưa có quyết định.

## 5. Trạng thái tài liệu

| Hạng mục | Trạng thái |
|---|---|
| Mô hình thương lượng giá | Đã chốt |
| IA hành khách/tài xế/admin | Đã chốt |
| Golden screens | Đã có đặc tả |
| Component library | Đã có đặc tả |
| Token | Đã có JSON |
| Accessibility | Đã có checklist |
| Implementation gap | Đã có |
| Dark mode | P1, chưa làm |
| Multi-stop / shared ride | P1/P2, chưa làm |
| Platform fee | MVP giả định 0%, có hook cấu hình |
| Brand mark/illustration | Dùng chữ S tạm; cần thiết kế asset riêng |

## 6. Thay đổi so với bản sơ bộ

- Bỏ mô hình super-app (đồ ăn, giao hàng, membership, Green Race).
- Bỏ giá cố định do app đặt; thay bằng offer/counter-offer.
- Adopt teal pastel/3D icon/floating tab của Green SM; asset riêng, không copy logo/mascot.
- Bỏ tab bar 5 icon trôi; dùng 4 tab + vai trò tài xế.
- Bổ sung toàn bộ state machine cho offer, trip, payment, cancellation, dispute.
- Bổ sung admin live ops, KYC, tranh chấp, escrow.

## 7. Quy ước đặt tên

- `Passenger` = người đi/xe; `Driver` = tài xế; `RideRequest` = yêu cầu chuyến; `RideOffer` = lời cháo giá; `Trip` = chuyến đã chốt.
- UI dùng “Bạn” cho hành khách, “Tài xế” cho driver; không dùng “khách hàng” trong microcopy.
- Giá: `120.000đ`, không `120,000 VNĐ`.
- Thời gian: `21:30`, ngày `19/11`, thời lượng `21 phút`.

## 8. Liên hệ với code hiện tại

Codebase hiện tại là app carpooling/Daily với `trips` + `bookings` giá cố định. Tài liệu này định nghĩa **sản phẩm đích**; `implementation-gap.md` mô tả phần tái dùng và phần phải xây mới. Không được coi các bảng `trips/bookings` hiện tại là mô hình chuyến đi mới nếu chưa có lớp chuyển đổi.
