# DESIGN.md — Điểm vào của bộ tài liệu thiết kế

> Nguồn: rút ra từ 14 screenshot iPhone của app Green SM v5.13.0 (Home, Hoạt động, Thông báo, Hồ sơ, Cài đặt, Cập nhật tài khoản, Thanh toán, Trung tâm hỗ trợ, Ưu đãi của tôi, Safety Centre, Hội viên, Đóng góp bản đồ).
> Trạng thái: **bản nháp v0.1**. Mọi số đo (px, hex) là **ước lượng từ ảnh** (ảnh ~3x, quy về pt). Cần đối chiếu với file Figma/code thật nếu có. Mục nào đánh dấu `[ĐỀ XUẤT]` là phần ảnh không có, tôi bổ sung để hệ thống đầy đủ.
> Lưu ý bản quyền: tài liệu mô tả **hệ thống thiết kế** (bố cục, quy tắc, token), không chép logo, minh họa 3D, ảnh banner hay mascot. App của bạn phải dùng tài sản (asset) riêng.

## Cách AI sử dụng bộ tài liệu này

Đọc theo thứ tự, và **không được thiết kế trước khi đọc xong mục 1-4 dưới đây**:

| File | Nội dung | Khi nào đọc |
|---|---|---|
| `DESIGN.md` (file này) | Triết lý, ưu tiên, luật cứng, checklist | Luôn đọc đầu tiên |
| `tokens.json` | Màu, font, spacing, bo góc, bóng, motion | Mọi lần dựng UI |
| `components.md` | Thông số và trạng thái từng component | Khi dùng component |
| `screens.md` | Cấu trúc từng màn hình mẫu (golden screens) | Khi thiết kế màn mới tương tự |
| `content-and-states.md` | Giọng văn, microcopy, trạng thái hệ thống, accessibility, anti-patterns | Khi viết chữ, xử lý lỗi/rỗng |

## 1. Bối cảnh sản phẩm (suy ra từ ảnh, hãy sửa nếu sai)

- **Loại app**: super-app di chuyển + đồ ăn + giao hàng + thuê xe + hội viên + gamification môi trường ("Green Race").
- **Người dùng**: đại chúng Việt Nam, dùng một tay, ngoài trời, thường vội. Có "Chế độ tối giản" dành cho người cao tuổi và trẻ em, nghĩa là độ tuổi và trình độ công nghệ rất rộng.
- **Mục tiêu giao diện**: từ lúc mở app đến lúc bấm đặt xe hoặc đặt món chỉ cần 1-2 chạm.
- **Non-goals** `[ĐỀ XUẤT, hãy xác nhận]`: không làm mạng xã hội, không làm trang tin tức dài, không để khuyến mãi che mất hành động đặt xe/đặt món.

## 2. Nguyên tắc thiết kế

**P1. Hành động chính trước, dịch vụ phụ sau.**
Trên Home thứ tự cố định: ô tìm kiếm → gợi ý cá nhân hóa → 2 dịch vụ chính (Đặt xe, Đặt đồ ăn) → lưới dịch vụ phụ → banner → gợi ý quán.
- Do: 2 thẻ dịch vụ chính luôn to hơn, nằm trên lưới dịch vụ phụ.
- Don't: đưa banner quảng cáo lên trên ô tìm kiếm hoặc 2 thẻ chính.
- Vì sao: 80% lượt dùng là đặt xe/đặt món.

**P2. Mềm mại và thân thiện, nhưng không đánh đổi độ rõ.**
Bo góc lớn, minh họa 3D pastel, giọng văn gần gũi ("Đặt món yêu thích cho bữa ăn hôm nay nhé.").
- Do: dùng minh họa để nhận diện dịch vụ; chữ vẫn là thứ chính.
- Don't: minh họa che chữ, hoặc dùng minh họa thay nhãn.

**P3. Một màu thương hiệu = một ý nghĩa "hành động".**
Teal (xanh ngọc) dành cho nút chính, link, trạng thái đang chọn, giá. Các màu khác chỉ mang nghĩa ngữ nghĩa: vàng = ưu đãi/mới/cảnh báo nhẹ, hồng = an toàn/khẩn cấp, xanh lá = môi trường/hội viên.
- Don't: tô màu trang trí tùy hứng; thêm màu thứ hai làm nút chính.

**P4. Kính mờ (glass) chỉ ở lớp nổi.**
Tab bar và ô tìm kiếm trên nền bản đồ dùng hiệu ứng kính. Nội dung chính (thẻ, danh sách, form) nằm trên nền đặc.
- Don't: đặt chữ nhỏ trực tiếp lên kính mờ không có lớp nền đảm bảo contrast.

**P5. Không bao giờ để màn hình "trống câm".**
Mọi danh sách đều có trạng thái rỗng gồm minh họa + một câu giải thích + (nếu hợp lý) một nút hành động.

**P6. Tin cậy khi đụng tới tiền và danh tính.**
Che thông tin nhạy cảm (chỉ 4 số cuối thẻ, `**3286` cho ví), hiển thị rõ trạng thái xác thực, có huy hiệu pháp lý ở cuối trang cài đặt.

## 3. Thứ tự ưu tiên khi các quy tắc xung đột

1. An toàn và pháp lý (Safety, huy hiệu Bộ Công Thương, điều khoản)
2. Accessibility (contrast, vùng chạm, cỡ chữ động)
3. Nguyên tắc P1-P6
4. Token và component trong tài liệu
5. Thẩm mỹ cá nhân của AI/designer

Ví dụ: muốn dùng chữ trắng trên nền teal nhạt cho đẹp nhưng contrast < 4.5:1 → ưu tiên 2 thắng, đổi sang chữ đậm hoặc nền teal đậm hơn (xem lưu ý contrast ở `content-and-states.md`).

## 4. Luật cứng cho AI (vi phạm = làm lại)

1. **Chỉ dùng token trong `tokens.json`.** Không hardcode hex, px, ms.
2. **Chỉ có 1 nút chính (primary) nổi bật mỗi màn hình/mỗi vùng cuộn.**
3. **Lưới 4pt**; lề trang 16pt; khoảng cách giữa thẻ cùng hàng 8-12pt.
4. **Vùng chạm tối thiểu 44x44pt.**
5. **Mọi component tương tác phải có đủ trạng thái**: default, pressed, disabled, loading; thêm focus và error cho input.
6. **Nhãn tiếng Việt có dấu đầy đủ**, thiết kế phải chịu được nhãn dài gấp 1.5 lần (ví dụ "Đưa đón sân bay" xuống 2 dòng; tên món bị cắt có dấu "…").
7. **Tiền tệ**: dùng dấu chấm ngăn cách nghìn và hậu tố `đ`, ví dụ `69.800đ`. Giá gốc gạch ngang nằm cạnh giá khuyến mãi. (Ảnh có chỗ lẫn `34,700 VNĐ`, xem mục 7: không bắt chước.)
8. **Ngày** dạng `dd/MM` (cùng năm) hoặc `dd/MM/yyyy`; **thời lượng** dạng `21 phút`.
9. **Không dùng emoji thay icon chức năng.** Emoji chỉ để trang trí tiêu đề thông báo/ưu đãi.
10. **Mỗi màn hình chỉ dùng một kiểu thanh đầu trang** (xem `components.md` mục TopBar) và cùng một kiểu nút Back toàn app.

## 5. Checklist nghiệm thu (AI phải tự chấm và báo cáo từng dòng)

- [ ] Mọi màu, cỡ chữ, spacing, radius, shadow đều lấy từ token
- [ ] Có đúng 1 CTA chính nổi bật
- [ ] Đủ trạng thái: loading, rỗng, lỗi, offline (nếu màn hình có dữ liệu)
- [ ] Contrast chữ ≥ 4.5:1 (chữ lớn ≥ 3:1), đã kiểm tra chữ trắng trên teal
- [ ] Vùng chạm ≥ 44pt, khoảng cách giữa các vùng chạm ≥ 8pt
- [ ] Hoạt động với Dynamic Type 130% mà không vỡ layout
- [ ] Có nhãn accessibility cho icon, ảnh, nút chỉ có icon
- [ ] Nhãn/microcopy đúng giọng văn (xem `content-and-states.md`)
- [ ] Safe area (notch, home indicator) được tôn trọng; tab bar nổi không che nội dung cuối trang
- [ ] Không dùng anti-pattern nào trong danh sách
- [ ] Không chép asset/logo/mascot của app khác

## 6. Quy trình làm việc đề xuất

1. Đọc tài liệu → 2. Nêu lại các ràng buộc áp dụng cho yêu cầu (3-5 dòng) → 3. Thiết kế → 4. Tự chấm checklist (mục 5) → 5. Liệt kê chỗ lệch tài liệu (nếu có) và lý do → 6. Đề xuất cập nhật tài liệu nếu phát hiện quy tắc còn thiếu.

## 7. Điểm không nhất quán thấy trong ảnh (không sao chép, nên chuẩn hóa)

| # | Phát hiện | Khuyến nghị |
|---|---|---|
| 1 | Nút Back có 2 kiểu: mũi tên trần (Cập nhật tài khoản, Thanh toán, Safety) và nút vuông trắng bo góc (Trung tâm hỗ trợ, Hội viên) | Chọn 1 kiểu cho toàn app |
| 2 | Trường "Nhóm khách hàng" lại có placeholder "Chọn danh xưng" (trùng trường Xưng hô) | Sửa copy: "Chọn nhóm khách hàng" |
| 3 | "Safety Centre" tiếng Anh giữa app tiếng Việt, trong khi Home dùng "Trung tâm an toàn" | Thống nhất tên theo ngôn ngữ đã chọn |
| 4 | Tiền tệ lúc `34,700 VNĐ` (Hồ sơ), lúc `24.200đ` (Thanh toán) | Một định dạng: `34.700đ` |
| 5 | Hồ sơ dùng icon 3D, Tiện ích & Ưu đãi dùng icon phẳng trong ô xanh lá, Cài đặt dùng icon outline | Quy định rõ: 3D = dịch vụ/tính năng chính, outline = cài đặt/danh sách, phẳng màu = tiện ích phụ |
| 6 | Nút "Xóa tài khoản" là chữ đen đậm thường, không có màu cảnh báo | Hành động phá hủy nên có màu error và bước xác nhận |
| 7 | Hai biến thể teal cho nút chính (`#5EC9D1` nhạt và `#2CCBD3` đậm) | Chọn 1 màu nút chính, 1 màu cho trạng thái pressed |
| 8 | Safety Centre dùng ảnh chân dung người thật làm minh họa, khác hẳn phong cách 3D còn lại | Dùng minh họa cùng phong cách, tránh dùng ảnh stock |

## 8. Câu hỏi còn mở (cần bạn quyết)

1. Dark mode có làm không? Ảnh chỉ có light mode.
2. "Chế độ tối giản" cho người cao tuổi hoạt động thế nào (chữ to hơn, ít dịch vụ hơn)? Ảnh chỉ thấy dòng cài đặt.
3. Màn hình đặt xe, chọn điểm đón, theo dõi chuyến chưa có ảnh, cần bổ sung để viết `screens.md` đầy đủ.
4. Font chính thức là gì (xem `tokens.json`, mục typography)?
5. App của bạn là app gì, khác biệt gì so với app tham chiếu? Nếu trùng lĩnh vực, hãy chọn một màu thương hiệu và bộ minh họa khác.

## 9. Prompt mẫu để đưa cho AI

```
Hãy đọc DESIGN.md, tokens.json, components.md, screens.md, content-and-states.md trong thư mục này.
Nhiệm vụ: thiết kế màn hình <TÊN MÀN HÌNH> cho <MỤC ĐÍCH>.
Trước khi thiết kế: liệt kê 5 ràng buộc từ tài liệu áp dụng cho màn này.
Sau khi thiết kế: tự chấm checklist nghiệm thu (DESIGN.md mục 5), báo cáo từng dòng Đạt/Không đạt và lý do.
Nếu phải lệch tài liệu, nêu rõ chỗ lệch và đề xuất sửa tài liệu thay vì lặng lẽ lệch.
```
