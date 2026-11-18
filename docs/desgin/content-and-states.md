# content-and-states.md — Giọng văn, trạng thái hệ thống, accessibility, anti-patterns

## 1. Giọng văn (voice & tone)

- **Thân thiện, gần gũi, ngắn gọn.** Xưng "bạn", gọi tên người dùng khi chào ("Chào Vượng,"). Câu cuối thường có "nhé", "nào", "ngay" để tạo cảm giác nhẹ nhàng, nhưng không lạm dụng.
- **Hướng hành động**: nhãn nút bắt đầu bằng động từ ("Đặt xe ngay!", "Khám phá ngay!", "Bắt đầu dùng thử").
- **Khuyến mãi**: nói rõ giá trị + điều kiện (−25%, tối đa 150K). Dấu chấm than tối đa 1/câu. Emoji chỉ ở tiêu đề thông báo/ưu đãi.
- **Giữa lúc nhạy cảm (an toàn, thanh toán, xóa tài khoản, lỗi)**: nghiêm túc, rõ ràng, không đùa, không emoji.
- **Không** dùng từ lóng quá đà, viết tắt khó hiểu, hoặc trộn tiếng Anh vào nhãn chức năng (xem DESIGN.md mục 7 #3).

### Mẫu microcopy

| Tình huống | Mẫu (lấy cảm hứng từ ảnh) | Ghi chú |
|---|---|---|
| Placeholder tìm kiếm | "Bạn muốn đi đâu, ăn gì?" | Câu hỏi mở, ≤ 1 dòng |
| Gợi ý cá nhân hóa | "Đặt món yêu thích cho bữa ăn hôm nay nhé." | Câu mời, kết thúc "nhé." |
| Rỗng - lịch sử chuyến | "Lịch sử di chuyển của bạn sẽ hiển thị tại đây. Đặt xe vi vu ngay!" + nút "Đặt Xe Ngay" | Giải thích + dẫn hành động |
| Rỗng - ưu đãi | "Bạn chưa có mã ưu đãi nào. Hãy quay lại sau nhé." | Không có nút nếu không có hành động hữu ích |
| Rỗng - đóng góp | "Chưa có đóng góp nào…" | Có thể thêm gợi ý hành động |
| Nhắc xác thực | "Vui lòng hoàn tất xác minh danh tính bằng cách quét mặt hoặc giấy tờ tùy thân ngay hôm nay" | Nêu cách làm + thời điểm |
| Helper email | "Nhập email để nhận thông tin cập nhật và thông báo từ ứng dụng." | Nêu lợi ích của việc nhập |
| Lỗi mạng `[ĐỀ XUẤT]` | "Không thể kết nối. Kiểm tra mạng rồi thử lại nhé." + nút "Thử lại" | Nguyên nhân + cách xử lý |
| Xóa tài khoản `[ĐỀ XUẤT]` | "Xóa tài khoản? Bạn sẽ mất [hậu quả cụ thể]. Không thể hoàn tác." + "Xóa tài khoản" (đỏ) / "Giữ lại" | Nêu hậu quả, nút phá hủy đỏ |

### Định dạng dữ liệu

| Loại | Định dạng | Ví dụ |
|---|---|---|
| Tiền | `###.###đ` (dấu chấm nghìn, hậu tố `đ`) | `69.800đ`, `20.750đ/tháng` |
| Giá khuyến mãi + giá gốc | khuyến mãi bold màu `primaryText`, giá gốc gạch ngang `ink400` bên phải | `29.900đ` ~~`35.000đ`~~ |
| Rút gọn | `5k`, `50K`: chỉ trong huy hiệu/banner; trong nội dung ghi đầy đủ | `5k` trong chip, `50.000đ` trong chi tiết |
| Thời lượng | số + "phút" | `21 phút` |
| Ngày | `dd/MM` cùng năm, `dd/MM/yyyy` khác năm | `11/11`, `28/02/2027` |
| Số điện thoại | `+84 888 033 286` (có nhóm), có thể che giữa | |
| Số liệu lớn | ngăn nghìn bằng dấu chấm | `2.645 cây xanh` |
| Số thẻ/ví | `Tên 4 số cuối` hoặc `**` + 4 số | `Visa Card 6169`, `MoMo **3286` |

---

## 2. Trạng thái hệ thống

| Trạng thái | Giao diện | Quy tắc |
|---|---|---|
| **Loading lần đầu** | Skeleton cùng kích thước nội dung thật (ảnh, dòng chữ, giá) | Skeleton nhấp nháy `motion.duration.slow`; tắt khi Reduce Motion |
| **Loading hành động** (nút) | Spinner thay chữ trong nút, giữ kích thước; chặn bấm lại | Quá 8 giây → hiện thông báo "Đang mất nhiều thời gian hơn dự kiến" |
| **Pull to refresh** | Spinner chuẩn nền tảng | Chỉ cho danh sách |
| **Rỗng** | EmptyState: minh họa + 1-2 câu + (nút) | Tông nhẹ nhàng, không đổ lỗi người dùng |
| **Lỗi tải** | Minh họa lỗi + nguyên nhân + nút "Thử lại" | Không dùng mã lỗi kỹ thuật làm nội dung chính |
| **Lỗi input** | Viền `error`, thông báo ngay dưới ô, `bodySm` màu `error`, kèm icon để không chỉ dựa vào màu | Hiện khi rời ô hoặc khi gửi |
| **Offline** | Banner mỏng đầu trang "Không có kết nối" + dữ liệu cache, vô hiệu hóa hành động cần mạng | Tự ẩn khi có mạng lại |
| **Thành công** | Toast 3 giây hoặc màn xác nhận (thanh toán, đặt xe) | Toast không chứa nút quan trọng |
| **Chưa xác thực** | Huy hiệu `warning` + thẻ nhắc xác thực | Hạn chế tính năng nào thì nói rõ tính năng đó |
| **Được vô hiệu hóa** | `disabledBg` + `disabledText`; nếu cần, giải thích lý do bằng helper text | Không chỉ làm mờ mà không giải thích |

---

## 3. Accessibility

- **Contrast**: chữ thường ≥ 4.5:1, chữ lớn (≥ 18pt hoặc ≥ 14pt bold) ≥ 3:1, icon/viền thành phần giao diện ≥ 3:1.
  - ⚠ Phát hiện từ ảnh: chữ trắng trên `brand.primary` (#5EC9D1) chỉ đạt khoảng 2:1, và `primary` trên nền trắng cũng thấp. **Hành động**: nút chính dùng nền đậm hơn (khoảng `#1FA7B0` trở xuống, kiểm tra bằng công cụ) hoặc chữ `ink900` trên nền teal; link teal dùng `primaryText`.
  - ⚠ `ink400` (placeholder, icon không hoạt động) chỉ dùng cho nội dung phụ, không dùng cho thông tin quan trọng.
- **Vùng chạm**: ≥ 44x44pt (iOS) / 48x48dp (Android); khoảng cách giữa 2 vùng chạm ≥ 8.
- **Dynamic Type / cỡ chữ động**: hỗ trợ tới 130% (tối thiểu); các hàng ngang (chip, tab) chuyển sang cuộn ngang hoặc xuống dòng, không cắt chữ.
- **Screen reader**: mọi icon-only (tab bar, tìm kiếm, "⋯", đánh dấu đã đọc, nút gửi chat) có nhãn; ảnh banner chứa chữ có `accessibilityLabel` mô tả ưu đãi; chấm chưa đọc → "chưa đọc"; huy hiệu −25% đọc cùng thẻ cha ("Đặt xe, giảm 25%").
- **Thứ tự focus**: trên → dưới, trái → phải; trong thẻ có nhiều thành phần, đọc tiêu đề trước, nút hành động sau.
- **Không chỉ dựa vào màu**: lỗi, trạng thái chưa đọc, trạng thái chọn phải có thêm icon/hình dạng/chữ.
- **Reduce Motion / Reduce Transparency**: tắt auto-advance carousel, chuyển cảnh đàn hồi; với Reduce Transparency thì thay kính mờ bằng nền đặc `surface`.
- **Chế độ tối giản** (đã có trong cài đặt, nhắm tới người cao tuổi và trẻ em): đề xuất `[ĐỀ XUẤT]` — chữ ≥ 18pt, tab bar có nhãn, Home chỉ còn Đặt xe/Đặt đồ ăn + 4 dịch vụ phổ biến, bỏ banner tự chạy, nút lớn hơn (cao ≥ 56). Hãy xác nhận cách làm với nhóm sản phẩm.
- **Màu**: không để tông xanh ngọc/xanh lá là cách duy nhất để phân biệt trạng thái (mù màu xanh-lá/đỏ).

---

## 4. Localization

- Ngôn ngữ mặc định: tiếng Việt có dấu đầy đủ. Mọi chuỗi trong file ngôn ngữ, không nằm trong ảnh.
- Chừa chỗ cho chuỗi dài hơn 30-40% khi dịch sang tiếng Anh/ngôn ngữ khác; kiểm tra các nhãn 2 dòng.
- Chữ có dấu cần `lineHeight` đủ lớn (≥ 1.3x cỡ chữ) để dấu không bị cắt.
- Định dạng số, ngày, tiền theo locale; tên quốc gia, quốc tịch dùng danh sách chuẩn.

---

## 5. Anti-patterns (tuyệt đối không)

1. Hardcode hex/px/ms trong thiết kế hoặc code.
2. Hơn 1 nút Primary nổi bật trong cùng vùng nhìn.
3. Dùng teal làm màu trang trí; dùng nhiều hơn 1 màu nhấn cho hành động.
4. Đặt chữ nhỏ trực tiếp lên ảnh/kính mờ khi chưa có lớp nền đảm bảo contrast.
5. Đặt chữ chức năng quan trọng (giá, điều kiện, nút) bên trong ảnh banner.
6. Icon chỉ có hình, không nhãn, trong mọi điều hướng chính khi người dùng có thể không hiểu (với tab bar: bắt buộc có nhãn accessibility và hỗ trợ hiện nhãn).
7. Hai kiểu nút Back khác nhau trong cùng app; hai kiểu định dạng tiền khác nhau.
8. Trộn 3 phong cách icon (3D, outline, phẳng màu) trong cùng một nhóm danh sách.
9. Modal chồng modal; bottom sheet trên bottom sheet.
10. Hành động phá hủy (xóa, hủy) không có màu cảnh báo và không có bước xác nhận.
11. Placeholder dùng làm nhãn (nhãn luôn nằm ngoài ô); copy-paste placeholder sai (như "Chọn danh xưng" cho Nhóm khách hàng).
12. Hiển thị đầy đủ số thẻ, CCCD, hay thông tin nhạy cảm không cần thiết.
13. Carousel tự chạy không dừng được; marquee chữ không dừng được.
14. Skeleton khác kích thước nội dung thật (gây giật layout).
15. Dùng ảnh người thật làm minh họa chung chung khi hệ thống dùng minh họa 3D; chép logo, mascot, minh họa của app khác.
16. Thêm tính năng ngoài phạm vi (non-goals) chỉ vì "trông đẹp".

---

## 6. Ghi chú cập nhật tài liệu

Khi AI hoặc designer phát hiện quy tắc còn thiếu, ghi vào bảng dưới (không âm thầm lệch tài liệu):

| Ngày | Phát hiện | Đề xuất | Đã duyệt? |
|---|---|---|---|
| | | | |
