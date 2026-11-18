# components.md — Thông số và trạng thái component

> Mọi giá trị tham chiếu token trong `tokens.json` (viết dạng `size.xxx`, `radius.xxx`...). Số trong ngoặc là ước lượng từ ảnh.
> Mỗi component: **Mục đích → Cấu tạo → Thông số → Trạng thái → Quy tắc dùng / không dùng**.

---

## 1. TopBar (thanh đầu trang) — 3 biến thể, mỗi màn chỉ chọn 1

| Biến thể | Dùng cho | Cấu tạo |
|---|---|---|
| **A. Large title tab** | Màn tab gốc (Hoạt động, Thông báo) | Tiêu đề `titleLarge` căn trái, lề 16; icon hành động (tìm kiếm, "đánh dấu đã đọc") căn phải, vùng chạm 44 |
| **B. Back + title giữa** | Màn con (Cập nhật tài khoản, Thanh toán, Trung tâm hỗ trợ) | Nút Back trái, tiêu đề `title` ở giữa; link văn bản phải (ví dụ "Lịch sử", màu `primaryText`) |
| **C. Hero header** | Màn có minh họa mở đầu (Ưu đãi, Hội viên, Đóng góp bản đồ) | Nút Back trên nền gradient/minh họa; tiêu đề `titleLarge` + 1 dòng mô tả; minh họa 3D phải |

Quy tắc: toàn app dùng **một kiểu nút Back** (khuyến nghị: mũi tên trần 24pt, vùng chạm 44; nếu đặt trên ảnh/gradient thì nền tròn trắng 40pt). Khi cuộn, TopBar A/B có viền dưới `color.neutral.line` hoặc đổ bóng `elevation.chip`.

---

## 2. SearchBar (ô tìm kiếm nổi)

- **Mục đích**: điểm vào tìm điểm đến và món ăn (placeholder: "Bạn muốn đi đâu, ăn gì?").
- **Cấu tạo**: icon kính lúp 24 trái, placeholder `bodyLg` màu `ink400`.
- **Thông số**: cao `size.searchBarHeight` (~52), rộng = màn - 2x`pageGutter`, nền `surface`, `radius.pill`, `elevation.card`.
- **Trạng thái**: default; pressed (nền nhấn nhẹ); khi cuộn nổi cố định phía trên cùng, nội dung trượt phía dưới (z `floatingSearch`). Khi tap → mở màn tìm kiếm toàn màn hình, tự focus.
- **Don't**: không đặt nhiều hơn 1 ô tìm kiếm trên cùng màn; không dùng placeholder dài hơn 1 dòng.

---

## 3. FloatingTabBar (tab bar nổi dạng viên thuốc) + nút Trophy

- **Cấu tạo**: viên thuốc kính mờ chứa 4 tab (Trang chủ, Hoạt động, Thông báo, Tài khoản), **chỉ icon, không nhãn**; bên phải là 1 nút tròn riêng (cúp Green Race).
- **Thông số**: cao `size.tabBar.height` (~64), `radius.pill`, nền `overlay.glassFill` + blur `blur.glass` + viền `overlay.glassStroke`; icon 24; nút tròn `size.trophyButton` (60) cách tab bar 12; nổi cách đáy `tabBar.bottomOffset` trên safe area.
- **Trạng thái tab**: *inactive* icon `ink400`; *active* icon màu `primaryVivid`/trắng nằm trong viên thuốc phát sáng `elevation.glowActive` (nền teal nhạt), chuyển 250ms. Có chấm/badge đỏ cho thông báo chưa đọc `[ĐỀ XUẤT]`.
- **Quy tắc**: nội dung cuộn phải có padding đáy ≥ `tabBar.height + 32` để mục cuối không bị che. Tab bar ẩn trên màn con (Back + title) và màn có CTA dính đáy.
- **Accessibility (bắt buộc)**: icon-only nên có `accessibilityLabel` ("Trang chủ", "Hoạt động"...) và khi bật Dynamic Type lớn hoặc Chế độ tối giản thì hiện nhãn dưới icon.
- **Don't**: không thêm tab thứ 5 trong viên thuốc; nút Trophy là lối tắt, không phải tab.

---

## 4. ServiceHeroCard (thẻ dịch vụ chính: Đặt xe, Đặt đồ ăn)

- **Cấu tạo**: tiêu đề `section` (bold) góc trên trái; huy hiệu ưu đãi (tùy chọn) dưới tiêu đề; minh họa 3D góc dưới phải, cắt ra ngoài mép được.
- **Thông số**: 2 thẻ/hàng, cách nhau 8-12; cao `size.serviceHeroCardHeight` (~96); `radius.xl`; nền `gradient.tileTealBase` (xe) / `gradient.tileWarmBase` (đồ ăn); viền 1px trắng trong suốt.
- **Trạng thái**: pressed co 0.98 + tối nhẹ; loading dùng skeleton cùng kích thước.
- **Quy tắc**: luôn xếp trên lưới dịch vụ phụ; tối đa 2 thẻ chính.

## 5. ServiceTile (ô dịch vụ phụ trong lưới 4 cột)

- **Cấu tạo**: icon 3D 48 trên, nhãn `body` căn giữa dưới; góc trên phải có huy hiệu (−25%, MỚI) lấn ra ngoài mép.
- **Thông số**: 4 cột, ô ~85x90, `radius.lg`, nền `surface`, khoảng cách 8; nhãn tối đa 2 dòng.
- **Trạng thái**: default, pressed; không có trạng thái disabled (ẩn dịch vụ không khả dụng thay vì làm mờ) `[ĐỀ XUẤT]`.
- **Dùng**: tối đa 8 ô trên Home, còn lại vào "Xem tất cả".

---

## 6. Badge / Pill

| Loại | Nền | Chữ | Ví dụ |
|---|---|---|---|
| Promo | `semantic.promoBg` | `semantic.promoText` | −25%, MỚI |
| Media chip | `overlay.scrimMedia` | trắng, `caption` | 🕘 21 phút, 5k (đè trên ảnh) |
| Trạng thái cảnh báo | `semantic.warning` | trắng, `caption` | Chưa xác thực |
| Số lượng quyền lợi | `semantic.success` | trắng | x20, x25 |
| Hạng/Member | `surface` + viền `line` | `ink900` | Member |

Quy tắc: cao 20-24, padding ngang 8-10, `radius.pill`. Chữ trắng trên `warning` vàng đậm chỉ đạt contrast thấp, ưu tiên chữ `ink900` hoặc nền đậm hơn.

---

## 7. FoodCard (thẻ gợi ý món)

- **Cấu tạo (dọc)**: ảnh vuông 115 `radius.lg` (chip thời lượng + chip giảm giá đè góc dưới trái) → tên món `bodyLg` tối đa 2 dòng → giá `price` (màu `primaryText`) + giá gốc `priceStrike`.
- **Cuộn ngang** có peek thẻ kế tiếp (thẻ thứ 3 bị cắt mép phải) để gợi ý có thể vuốt.
- **Trạng thái**: skeleton ảnh + 2 thanh chữ; ảnh lỗi → nền `primaryTint` + icon bát đũa. Thẻ không có ảnh dùng minh họa mặc định (như thẻ "Mì Trộn" có nút `+` thêm nhanh).
- **Quy tắc**: nút `+` thêm nhanh góc dưới phải ảnh chỉ khi món không cần chọn tùy chọn.

## 8. BannerCarousel + PageDots

- Banner rộng = màn - 2x16, cao ~152, `radius.lg`, ảnh `cover`; nội dung chữ nằm trong ảnh (cần bản gốc đã chứa chữ, nên **không đặt chữ chức năng quan trọng trong ảnh**: không dịch được, không đọc được bằng screen reader → thêm `accessibilityLabel`).
- Dots: tròn 6 màu `line`; trang đang chọn là **viên thuốc dài** 24x6 màu `primary`.
- Tự chuyển mỗi `motion.duration.carouselAutoAdvance`; dừng khi người dùng chạm/vuốt; tắt khi Reduce Motion.
- Mỗi banner có 1 đích điều hướng; có dòng điều kiện áp dụng (chữ nhỏ) ở góc dưới.

## 9. SectionHeader

- Trái: `section` (bold); phải (tùy chọn): link "Xem tất cả" `bodyLg` màu `ink900` (ảnh dùng chữ đen đậm, không có mũi tên). `[ĐỀ XUẤT]` thêm chevron để rõ là điều hướng.
- Cách khối phía trên 24, cách nội dung phía dưới 12.

---

## 10. Button

| Loại | Nền | Chữ | Viền | Dùng cho |
|---|---|---|---|---|
| **Primary** | `brand.primary` | trắng bold `bodyLg` | - | CTA chính: Đặt Xe Ngay, Bắt đầu dùng thử, Xem tiến trình chi tiết |
| **Tonal** | `brand.primaryTint` | `primaryText` | 1px `primaryBorder` | CTA phụ trong nội dung/thông báo: Khám phá ngay!, Đặt xe ngay! |
| **Compact accent** | `primaryVivid` | trắng | - (+ shadow `ctaButtonSmall`) | Hành động nhanh trong dòng: Nạp tiền |
| **Soft white** | `surface` | `ink900` | shadow `chip` | Xem ưu đãi (đặt trên nền ảnh/bản đồ) |
| **Text link** | trong suốt | `primaryText` | - | Lịch sử, Thêm phương thức thanh toán |
| **Destructive text** | trong suốt | `error` | - | Xóa tài khoản `[ĐỀ XUẤT]` |
| **Disabled** | `disabledBg` | `disabledText` | - | Cập nhật khi chưa có thay đổi |

Thông số: cao 52 (compact 36), `radius.sm` (primary) hoặc `radius.pill` (compact), ngang tối thiểu 88 để dễ chạm.
Trạng thái: default → pressed (tối 8%, co 0.98) → loading (spinner thay chữ, giữ nguyên kích thước, chặn chạm lại) → disabled.
Quy tắc: 1 Primary/màn; CTA dính đáy (Membership) tách thanh riêng có giá bên trái, nút bên phải.

---

## 11. Form: TextField, Select, DatePicker

- **Cấu tạo**: nhãn trên ô (`bodyLg`, bold nhẹ) → ô nhập cao 52, `radius.md`, nền `surface`, viền 1px `line` + bóng `elevation.card` → helper text dưới (`bodySm`, `ink500`).
- **Select**: chevron xuống phải; **DatePicker**: icon lịch phải; **Read-only** (số điện thoại): nền `disabledBg`, chữ `ink700`, không viền.
- **Trạng thái**: default, focus (viền `primary` 2px), filled, error (viền `error` + thông báo đỏ dưới ô), disabled/read-only.
- **Nút gửi form** (`Cập nhật`) nằm cố định đáy, **disabled cho đến khi có thay đổi hợp lệ**.
- **Quy tắc**: trường tùy chọn ghi "(không bắt buộc)" trong nhãn; trường bắt buộc không cần dấu `*` nếu mặc định là bắt buộc.

## 12. ListRow (dòng danh sách/cài đặt)

- Icon outline 24 màu `ink500` trái → nhãn `bodyLg` (+ mô tả phụ `bodySm` `ink500` dưới, ví dụ "Được tối ưu hóa cho người cao tuổi và trẻ em") → chevron phải `ink400`.
- Cao ≥ 56, phân cách bằng khoảng trắng hoặc đường kẻ `line` (đồng nhất trong 1 màn).
- Nhóm có tiêu đề `section`. Hành động cuối ("Đăng xuất") căn giữa, icon + chữ.

## 13. ActionGridItem (lưới tác vụ 2 cột trên Hồ sơ)

- Ô trắng `radius.lg`, icon 3D 40 trái + nhãn `bodyLg`, cao ~56; 2 cột, cách nhau 8.
- Nhóm "Tiện ích & Ưu đãi" dùng icon phẳng màu `semantic.success` trong ô vuông bo `successTint` 44 (đã nêu ở DESIGN.md mục 7 #5).

## 14. NotificationItem

- Cấu tạo: vòng tròn mint 48 (`successTint`) icon vé xanh lá | tiêu đề `bodyLg` bold (tối đa 2 dòng) + ngày `bodySm` căn phải + chấm chưa đọc `primary` 8pt | nội dung `body` `ink500` (tối đa 3 dòng, cắt "…") | nút Tonal | ảnh banner `radius.sm` full-width trong cột nội dung.
- Trạng thái: chưa đọc (có chấm; nên làm tiêu đề đậm hơn), đã đọc (không chấm, màu nhạt hơn) `[ĐỀ XUẤT]`; skeleton khi tải.
- Hành động "đánh dấu tất cả đã đọc" ở TopBar phải (icon 2 dấu tích).

## 15. FilterChips (nhóm chip lọc ngang)

- Cao `size.chipHeight`, padding ngang 16, `radius.pill`; **active**: nền `ink700` chữ trắng; **inactive**: nền `surface` + shadow `chip` chữ `ink900`. Cuộn ngang được khi vượt chiều rộng. Chỉ chọn 1.
- Dùng cho: Di chuyển/Đồ ăn/Giao hàng/Xe theo giờ; Tất cả/Ưu đãi; Tất cả/Di chuyển/Đồ ăn.

## 16. PlanTabs + BenefitCard + StickyCTABar (màn Hội viên)

- **PlanTabs**: chip nhỏ trên nền gradient; active = trắng, inactive = trắng mờ.
- **Thẻ gợi ý**: nền `primaryTint` bán trong suốt, icon lấp lánh trái, tiêu đề + 1 dòng mô tả.
- **BenefitCard**: tiêu đề + "Xem tất cả >"; 3 cột, mỗi cột: huy hiệu `xN` (xanh lá) đè trên icon tròn nền kem, dòng đậm mô tả lợi ích ("Giảm 20%"), nhãn dịch vụ `ink500`.
- **StickyCTABar**: nền trắng, trái: dòng nhỏ xanh lá ("1 tháng dùng thử") + giá bold; phải: Primary. Nằm trên safe area, thay tab bar.

## 17. StatCard (Green Race)

- Thẻ gradient `cardGreenRace`, nhãn tab góc trên trái (icon cúp + "Green Race"), số lớn `display` màu `primaryDeep` + đơn vị `bodyLg`, dòng mô tả, huy hiệu hạng 3D bên phải, dải thông số phụ (cuộn ngang/ marquee), Primary full-width phía dưới.
- Số liệu luôn có đơn vị; nếu có dải marquee thì phải dừng được và có bản chữ tĩnh cho screen reader.

## 18. InfoCard / PromoStrip

- **InfoCard (nhắc xác thực)**: trắng, `radius.xl`, ảnh minh họa trái 56, tiêu đề + mô tả 2 dòng; nhiều thẻ có PageDots (3 chấm).
- **PromoStrip (quà tặng)**: gradient `primaryTint`, minh họa 3D lấn ra mép trái trên, tiêu đề + mô tả + chevron phải.
- **SafetyCard**: nền `safetyTint`, tiêu đề đậm, mô tả, khiên mờ phải + nút mũi tên trắng vuông bo 44. Dành riêng cho an toàn, không dùng cho khuyến mãi.

## 19. PaymentMethodRow

- Logo phương thức 24 trái | tên + số đã che (`Visa Card 6169`, `MoMo **3286`) | chevron. Dòng đề xuất (Thẻ E-Green) có số dư `ink500` bên dưới và nút Compact accent "Nạp tiền" phải.
- Nhóm theo tiêu đề: Thẻ tín dụng/Ghi nợ, Ví điện tử, Phương thức đề xuất. "Thêm phương thức thanh toán" = Text link kèm dấu `+`.
- **Bảo mật**: không bao giờ hiển thị đủ số thẻ; trạng thái lỗi/thẻ hết hạn dùng chip `error` `[ĐỀ XUẤT]`.

## 20. SupportGreeting + ChatInput

- Thẻ chào gradient teal nhạt, lời chào cá nhân hóa ("Chào Vượng,") `title` + câu hỏi, mascot bên phải; dưới là ô nhập chat cùng thẻ: icon lấp lánh, placeholder, nút gửi (icon máy bay giấy `primary`).
- Ô chat có viền gradient mảnh để báo hiệu AI. Nhãn "AI" nên hiển thị rõ `[ĐỀ XUẤT]`.

## 21. EmptyState

- Minh họa 3D xám-xanh nhạt ~120 (xe ngủ, vé % rỗng, bản đồ) + 1-2 câu `body` căn giữa + (tùy chọn) Primary.
- Căn giữa dọc theo vùng nội dung, không để sát đầu trang. Chi tiết copy: `content-and-states.md`.
