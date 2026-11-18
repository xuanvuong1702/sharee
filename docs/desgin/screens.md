# screens.md — Cấu trúc các màn hình mẫu (golden screens)

> Mô tả từ trên xuống dưới. Dùng làm khuôn khi thiết kế màn mới tương tự. Tên component trỏ về `components.md`. Lề trang = `spacing.pageGutter` (16) nếu không nói khác.
> Màn chưa có trong ảnh (đặt xe, chọn điểm đón, theo dõi chuyến, giỏ hàng, thanh toán đơn, đánh giá) cần chụp thêm để mô tả.

## Sơ đồ điều hướng (IA)

```
Tab bar nổi
├─ Trang chủ
│   ├─ Tìm kiếm → (kết quả)
│   ├─ Đặt xe / Đặt đồ ăn / Xe máy / Liên tỉnh / Giao hàng / Đưa đón sân bay
│   ├─ Hội viên (Green Pass / Plus / VIP / Tùy chọn)
│   ├─ Mua xe VinFast / VinBus / Thuê xe tự lái
│   └─ Xem ưu đãi
├─ Hoạt động  [chip: Di chuyển | Đồ ăn | Giao hàng | Xe theo giờ]
├─ Thông báo  [chip: Tất cả | Ưu đãi]
├─ Tài khoản
│   ├─ Cập nhật tài khoản (hồ sơ, xác thực, xóa tài khoản)
│   ├─ Green Race (tiến trình chi tiết)
│   ├─ Gia đình / Doanh nghiệp
│   ├─ Tác vụ: Thanh toán, Mã khuyến mại, Trung tâm hỗ trợ, Trung tâm an toàn
│   ├─ Tiện ích & Ưu đãi: Hạng thành viên, Hội viên, Thẻ quà tặng, Giới thiệu bạn bè
│   ├─ Hỗ trợ & Hợp tác: Trở thành tài xế, Đóng góp bản đồ
│   └─ Cài đặt chung: Quốc gia, Ngôn ngữ, Chế độ tối giản, Đăng nhập & bảo mật, Địa chỉ đã lưu, Hóa đơn, Đánh giá ứng dụng, Hợp đồng sử dụng dịch vụ, Kiểm soát quyền riêng tư, Đăng xuất
└─ (Nút Trophy) → Green Race
```

---

## S1. Trang chủ (Home)

- **Nền**: bản đồ mờ + lớp gradient trắng-xám từ trên xuống; nội dung cuộn.
- **Từ trên xuống**:
  1. SearchBar (cách status bar ~36)
  2. Dòng gợi ý AI: icon lấp lánh + câu cá nhân hóa `section` + nút "⋯" phải (ẩn/tuỳ chỉnh gợi ý)
  3. Hàng FoodCard cuộn ngang (3 thẻ, peek) + nút Soft white "Xem ưu đãi"
  4. 2 ServiceHeroCard (Đặt xe có huy hiệu −25%, Đặt đồ ăn)
  5. SectionHeader "Dịch vụ khác" + "Xem tất cả" → lưới ServiceTile 4 cột x 2 hàng
  6. BannerCarousel + PageDots
  7. SectionHeader "Gợi ý quán ngon" → thẻ quán cuộn ngang (ảnh poster lớn ~160x230, tên quán 2 dòng)
  8. Padding đáy cho tab bar
- **Khi cuộn**: SearchBar bám đỉnh, nền chuyển sang kính mờ; nội dung trượt dưới nó.
- **Hành động chính**: chạm thẻ Đặt xe hoặc Đặt đồ ăn.
- **Trạng thái**: loading = skeleton cho FoodCard/banner (không skeleton cho thẻ dịch vụ vì tĩnh); không có gợi ý cá nhân → ẩn khối 2-3, giữ nguyên thứ tự còn lại; offline = banner đầu trang + dữ liệu cache.

## S2. Hoạt động

- TopBar A "Hoạt động" + icon tìm kiếm phải; FilterChips (4 chip, cuộn ngang).
- Có dữ liệu: danh sách chuyến/đơn theo thời gian `[ĐỀ XUẤT: thẻ có trạng thái, điểm đi-đến, giá, nút Đặt lại]`.
- **Rỗng** (đã có trong ảnh): minh họa xe ngủ + "Lịch sử di chuyển của bạn sẽ hiển thị tại đây. Đặt xe vi vu ngay!" + Primary "Đặt Xe Ngay". Nền `neutral.bg`.

## S3. Thông báo

- TopBar A "Thông báo" + icon đánh dấu tất cả đã đọc; FilterChips (Tất cả | Ưu đãi).
- Danh sách NotificationItem, mới nhất trên cùng; nhóm theo ngày `[ĐỀ XUẤT]`.
- Mỗi mục có tối đa 1 nút hành động và 1 banner. Banner đã dùng lại cùng hình ảnh với Home, hãy ưu tiên tái sử dụng asset.
- Trạng thái: loading skeleton; rỗng "Chưa có thông báo nào"; lỗi tải có nút "Thử lại".

## S4. Tài khoản (Hồ sơ)

- Nền gradient `pageTopProfile`.
- Từ trên xuống: avatar 3D 72 (có huy hiệu cảnh báo nếu chưa xác thực) + tên `title` + chevron + số điện thoại `bodySm`; chip hạng "Member"; carousel InfoCard (nhắc xác thực danh tính, nhắc xác thực email) + dots; StatCard Green Race; 2 thẻ dịch vụ Gia đình/Doanh nghiệp (kiểu ServiceHeroCard thấp hơn); nhóm "Tác vụ" (ActionGridItem 2x2); nhóm "Tiện ích & Ưu đãi" (2x2) + PromoStrip; nhóm "Hỗ trợ & Hợp tác" (ListRow); nhóm "Cài đặt chung" (ListRow) + Đăng xuất + phiên bản + huy hiệu Bộ Công Thương.
- Quy tắc: số điện thoại có thể che một phần `[ĐỀ XUẤT]` khi chụp màn hình chia sẻ.

## S5. Cập nhật tài khoản

- TopBar B "Cập nhật tài khoản". Avatar 72 + nút sửa (bút) góc dưới phải; tên; số điện thoại; huy hiệu "Chưa xác thực".
- Carousel thẻ xác thực (danh tính, email) + dots.
- Nhóm "Thông tin cơ bản": Select Xưng hô, Select Nhóm khách hàng, TextField Họ Tên, Select Giới tính, DatePicker Ngày sinh, Select Quốc tịch, TextField read-only Số điện thoại, TextField Email (không bắt buộc) + helper text.
- Đáy cố định: Button Primary "Cập nhật" (disabled đến khi có thay đổi) + Destructive text "Xóa tài khoản".
- Cần: validate khi rời ô (blur), thông báo lỗi dưới ô, xác nhận 2 bước trước khi xóa tài khoản.

## S6. Phương thức thanh toán

- TopBar B + link "Lịch sử" phải.
- Nhóm: Thẻ tín dụng/Ghi nợ (PaymentMethodRow x N), Ví điện tử (Apple Pay, MoMo, ShopeePay), Phương thức đề xuất (Thẻ ví nội bộ + Nạp tiền), Text link "Thêm phương thức thanh toán".
- Trạng thái: rỗng nhóm → chỉ hiển thị tiêu đề nhóm cùng nút thêm; thẻ hết hạn → chip lỗi; chọn mặc định = dấu tích/nhãn "Mặc định" `[ĐỀ XUẤT]`.

## S7. Trung tâm hỗ trợ

- TopBar B (Back kiểu nút vuông trắng) "Trung tâm hỗ trợ".
- Từ trên xuống: SupportGreeting + ChatInput; SafetyCard "Hỗ trợ an toàn chuyến" (luôn hiển thị nổi bật); thẻ danh sách "Bạn cần hỗ trợ gì?" (Di chuyển, Giao hàng, Đồ ăn, Tài khoản và dịch vụ, mỗi dòng có icon 3D 40 + chevron); thẻ "Yêu cầu của tôi" (icon + mô tả + chevron).
- Nền `neutral.bg`; các khối là thẻ trắng `radius.xl` cách nhau 16.

## S8. Ưu đãi của tôi

- TopBar C: tiêu đề + mô tả + minh họa điện thoại/voucher phải; dưới là vùng nền `bg`.
- Tiêu đề phụ "🎁 Ưu đãi xịn, dùng ngay!" + link "Lịch sử" kèm icon đồng hồ; FilterChips (Tất cả, Di chuyển, Đồ ăn).
- Danh sách voucher `[ĐỀ XUẤT: thẻ vé có phần cắt răng cưa, giá trị lớn, điều kiện, hạn dùng, nút Dùng ngay]`.
- **Rỗng** (đã có): minh họa vé % + "Bạn chưa có mã ưu đãi nào. Hãy quay lại sau nhé."

## S9. Safety Centre

- TopBar C đơn giản (Back + tiêu đề lớn) + hero có minh họa khiên và avatar xác thực trên nền bản đồ xanh.
- Thẻ danh sách 4 dòng: Bảo hiểm chuyến (áp dụng mọi chuyến), Camera S2S (tùy chỉnh từng chuyến), Theo dõi chuyến (tùy chỉnh từng chuyến), Liên hệ khẩn cấp. Mỗi dòng: icon outline, tiêu đề, mô tả, chevron.
- Ưu tiên pháp lý/an toàn: cho phép thao tác khi mạng yếu, không đặt quảng cáo.

## S10. Hội viên (Membership)

- TopBar C Back nút vuông + "Lịch sử"; nền gradient `pageTopMembership`.
- Tiêu đề lớn căn giữa "Tìm gói hội viên phù hợp với bạn"; PlanTabs; thẻ gợi ý; hero 3D giữa; tên gói `titleLarge` + khẩu hiệu; BenefitCard; 2 ListRow thẻ trắng (Điều khoản sử dụng gói, Hướng dẫn sử dụng gói).
- StickyCTABar: "1 tháng dùng thử / 20.750đ/tháng" + Primary "Bắt đầu dùng thử".
- Quy tắc minh bạch giá: hiển thị rõ giá sau dùng thử, điều kiện gia hạn tự động `[ĐỀ XUẤT: bắt buộc]`.

## S11. Đóng góp bản đồ

- Hero header gradient `heroMapContribute` + minh họa bản đồ + tiêu đề trắng/mô tả.
- 3 ListRow (icon xám trong vòng tròn 48, tiêu đề đậm + mô tả, chevron) có đường kẻ; thẻ "Bảng xếp hạng" nền xám nhạt với icon cúp vàng; "Đóng góp của tôi >" + EmptyState nhỏ "Chưa có đóng góp nào…".

## S12. Thông báo kiểu lưới trang chủ cuộn (biến thể của S1)

- Khi cuộn xuống, SearchBar nổi lên đầu, thẻ Đặt xe/Đặt đồ ăn trượt dưới SearchBar bị cắt đẹp (xem ảnh). Khi AI dựng cần giữ: SearchBar z-index trên nội dung, nội dung có padding đầu cho không bị che lúc chưa cuộn.

---

## Mẫu bố cục tổng quát

| Loại màn | TopBar | Nền | Khối chính | Đáy |
|---|---|---|---|---|
| Tab gốc (danh sách) | A | `bg` | FilterChips + danh sách | Tab bar nổi |
| Cài đặt/danh sách | B | `bg` hoặc gradient nhẹ | Nhóm ListRow | Tab bar nổi hoặc không |
| Form | B | `bg` | TextField xếp dọc | Nút cố định đáy |
| Marketing/gói | C | gradient | Hero + thẻ lợi ích | StickyCTABar |
| Rỗng | giữ nguyên | `bg` | EmptyState | Tab bar nổi |
