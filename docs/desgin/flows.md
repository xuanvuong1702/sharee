# flows.md — Luồng người dùng và edge cases

> Mỗi flow ghi: mục tiêu, precondition, các bước, trạng thái, lỗi, microcopy. Screen ID trỏ `screens.md`.

## F1. Đăng ký / đăng nhập

**Mục tiêu:** vào Home ≤ 30 giây.

1. Splash kiểm tra session.
2. Chưa đăng nhập → Auth sheet:
   - Logo, headline, trust chips.
   - Nhập SĐT.
   - Gửi OTP.
3. OTP:
   - 6 ô, auto-fill từ SMS (P1).
   - Countdown 60s, gửi lại.
   - Sai 5 lần → khoá 15 phút.
4. OTP đúng:
   - Tạo user level 1.
   - Nếu chưa có tên → onboarding tên/avatar (P1).
   - Vào Home.
5. Lỗi:
   - SĐT sai định dạng: inline error.
   - OTP sai: “Mã chưa đúng. Còn 4 lần thử.”
   - Mất mạng: banner offline + nút thử lại.

**Không được:** hiển thị OTP trong UI production; hiện tại dev có thể expose nhưng phải tắt ở production.

## F2. Đặt chuyến — đặt giá

**Precondition:** đã đăng nhập, location permission (hoặc nhập tay).

1. Home discovery:
   - Search “Bạn muốn đi đâu?”.
   - Hoặc chọn hero card `Đặt chuyến ngay` / `Đặt lịch`.
   - Dịch vụ: xe máy, 4 chỗ, 7 chỗ, sân bay.
2. Map picker:
   - Điểm đón (GPS hoặc search).
   - Điểm đến.
   - Thời gian: Bây giờ / Đặt lịch.
   - Loại xe.
3. Nhập giá:
   - Text field “Giá bạn muốn trả”.
   - Stepper ±10.000.
   - Không tự điền giá app.
   - Hiển thị “Tài xế có thể trả giá khác”.
4. Ghi chú (optional): “Tôi có 2 vali”.
5. Chọn “Tìm tài xế”.
6. Confirm sheet:
   - Route, giá, phương thức thanh toán, chính sách huỷ.
   - CTA “Gửi yêu cầu”.
7. Request `searching`:
   - Map hiện vòng radar.
   - Bottom sheet: “Đang tìm tài xế gần bạn”.
   - Timer + huỷ.
   - Khi có offer đầu tiên → auto mở Offers.
8. Nếu hết 2 phút không offer:
   - “Chưa có tài xế nhận giá này.”
   - Gợi ý: tăng giá / mở quote / đổi loại xe / huỷ.
9. Không được tự đổi giá.

## F3. Đặt chuyến — mở quote

1. Chọn “Để tài xế báo giá”.
2. Không nhập giá; hiển thị “Tài xế sẽ gửi giá cho bạn”.
3. Request `searching` 3 phút.
4. Offers list:
   - Mỗi offer có giá, ETA, driver.
   - Sort mặc định: đến sớm.
5. Chọn offer → confirm.
6. Nếu không offer → “Chưa có tài xế báo giá. Thử mở rộng thời gian hoặc đổi loại xe.”

## F4. Nhận và chọn offer

1. Push/SignalR báo “Có 3 tài xế gửi giá”.
2. Offers sheet:
   - Header: route + giá passenger.
   - Countdown.
   - Danh sách offer.
   - Sort chips: Giá thấp / Đến sớm / Uy tín.
3. Offer card:
   - Giá.
   - Chênh lệch (nếu counter): `+20.000đ`.
   - ETA đến pickup.
   - Driver: avatar, tên, sao, số chuyến, KYC.
   - Xe: hãng/màu/biển.
   - Tin nhắn template (optional).
4. Tap offer → Driver profile sheet:
   - Ảnh xe, biển số, đánh giá, chuyến đã đi.
   - Giá + ETA.
   - CTA “Chọn tài xế”.
5. Confirm:
   - “Chốt chuyến với Minh?”
   - Giá, ETA, phương thức.
   - CTA “Chốt chuyến”.
6. Thành công:
   - Request matched.
   - Offer khác biến mất.
   - Trip screen: driver arriving.
   - Chat thread mở.
7. Offer hết hạn:
   - Card mờ, label “Đã hết hạn”.
   - Không tap được.
8. Driver rút offer:
   - Card biến mất, toast “Tài xế đã rút giá.”

## F5. Counter-offer

### Driver → Passenger

1. Driver request detail → “Trả giá”.
2. Input giá mới, hiển thị chênh lệch so với giá passenger.
3. Gửi.
4. Passenger nhận notification + offer card `Đề nghị giá`.
5. Passenger:
   - Accept.
   - Decline.
   - Counter lại (1 lần).
6. Nếu passenger counter:
   - Driver nhận, có 90s accept/decline.
7. Sau 2 lượt counter, chỉ còn accept/decline.
8. Hết hạn → offer expired.

### UI rules

- Không giấu giá gốc.
- Không làm tròn giá.
- Không tự thêm phí.
- Countdown hiển thị rõ.
- Không cho counter thấp hơn 0 hoặc cao hơn 10.000.000đ.

## F6. Driver nhận chuyến

1. Driver online:
   - Kiểm tra KYC, giấy tờ xe, xe active.
   - Nếu thiếu → chặn và mở KYC.
2. Radar:
   - Map, request pins.
   - List request: pickup distance, dropoff, giá passenger, thời gian.
   - Filter: bán kính, loại xe, giá tối thiểu.
3. Request detail:
   - Passenger rating, pickup/dropoff, giá, note.
   - Accept / Counter / Bỏ qua.
4. Accept:
   - Confirm “Nhận chuyến với giá 120.000đ?”
   - Nếu passenger đã chọn driver khác → “Chuyến đã có tài xế.”
5. Nhận thành công:
   - Trip active.
   - Navigate đến pickup.
   - Chat/call mở.
6. Counter:
   - Input giá, gửi, chờ.
7. Offer hết hạn → biến mất.

## F7. Tài xế đến điểm đón

1. Driver bấm “Đã đến”.
2. Passenger nhận push + banner “Tài xế đã đến”.
3. Driver thấy:
   - Nút “Gọi” / “Nhắn”.
   - Timer chờ 5 phút.
   - Nút “Bắt đầu chuyến” disabled đến khi passenger lên? (MVP: driver tự xác nhận).
4. Passenger thấy:
   - Biển số, màu xe, vị trí.
   - Nút “Tôi đã lên xe” (optional).
5. Nếu quá 5 phút:
   - Driver có thể huỷ với lý do “Passenger không đến”; phí huỷ theo chính sách.
6. Nếu passenger huỷ:
   - Driver nhận thông báo, trip cancelled.

## F8. Trong chuyến

1. Driver bấm “Bắt đầu chuyến”.
2. Passenger thấy:
   - Map + route.
   - ETA.
   - Driver card.
   - Nút Chia sẻ, SOS, Chat, Gọi.
   - Nút “Kết thúc” chỉ driver.
3. Nếu lệch route > 500m:
   - Cảnh báo passenger (P1).
4. Nếu dừng > 5 phút:
   - Cảnh báo (P1).
5. SOS:
   - Gọi 113.
   - Gửi vị trí + trip cho emergency contact + admin.
   - Admin live ops nhận.
6. Không cho passenger huỷ trong chuyến; chỉ báo sự cố.
7. Mất mạng:
   - App cache route, tiếp tục ghi vị trí; đồng bộ lại.

## F9. Hoàn tất & thanh toán

1. Driver bấm “Hoàn tất chuyến”.
2. Nếu online:
   - Escrow release (hoặc chờ passenger xác nhận 2h).
   - Payment `captured/released`.
3. Nếu cash:
   - Passenger xác nhận “Đã trả”.
   - Driver xác nhận “Đã nhận”.
4. Receipt:
   - Route.
   - Giá chốt.
   - Phụ phí (nếu có).
   - Phí nền tảng (nếu có).
   - Tip.
   - Phương thức.
   - Mã chuyến.
5. Rating:
   - 5 sao + tags + comment.
   - Tip (optional).
6. Nếu passenger không xác nhận sau 2h:
   - Auto release escrow.
7. Nếu có tranh chấp:
   - Escrow disputed.
   - Mở F12.

## F10. Huỷ chuyến

### Passenger

1. Tap Huỷ.
2. Hiển thị chính sách theo thời điểm:
   - Miễn phí / phí 10% / 20%.
3. Chọn lý do.
4. Confirm.
5. Nếu driver đã đến: phí hiển thị trước.
6. Hoàn tiền:
   - Online: hoàn phần còn lại.
   - Cash: không treo tiền.

### Driver

1. Tap Huỷ.
2. Chọn lý do bắt buộc.
3. Cảnh báo ảnh hưởng uy tín.
4. Nếu đã đến pickup: phạt theo chính sách.
5. Passenger nhận thông báo + tìm tài xế khác (nếu muốn).

## F11. Đánh giá & tip

1. Sau chuyến, sheet đánh giá:
   - 5 sao.
   - Tags: “Lái an toàn”, “Thân thiện”, “Đúng giờ”, “Xe sạch”.
   - Comment.
   - Tip: 10k/20k/50k/tuỳ chọn.
2. Gửi.
3. Tip online:
   - Trừ ví/thẻ, cộng driver earnings.
4. Tip cash:
   - Chỉ ghi nhận; không xử lý tiền.
5. Đánh giá ẩn danh với driver? (MVP: hiện tên viết tắt).

## F12. Tranh chấp

1. Từ receipt/chuyến → “Báo vấn đề”.
2. Chọn loại:
   - Không đến.
   - Giá khác.
   - Thái độ.
   - An toàn.
   - Mất đồ.
   - Khác.
3. Mô tả + bằng chứng (ảnh/PDF).
4. Gửi.
5. Trạng thái:
   - `open` → admin xem.
   - `investigating`.
   - `resolved` (release/refund/partial).
6. Escrow bị giữ.
7. Hai bên xem được bằng chứng của nhau (đã redact thông tin nhạy cảm).
8. Admin quyết định; thông báo.

## F13. Driver onboarding / KYC

1. Đăng ký tài xế:
   - SĐT.
   - Họ tên.
   - CCCD 2 mặt.
   - GPLX 2 mặt.
   - Đăng ký xe.
   - Bảo hiểm.
   - Selfie.
2. Validate:
   - Đủ 18–80.
   - Giấy tờ còn hạn.
   - Không trùng CCCD/GPLX.
3. Gửi → pending.
4. Admin duyệt/từ chối.
5. Approved → online được.
6. Sắp hết hạn → nhắc trước 30 ngày.
7. Hết hạn → auto offline, chặn nhận chuyến.

## F14. Đặt lịch (P1)

1. Chọn “Đặt lịch”.
2. Chọn ngày/giờ (tối thiểu 30 phút tới; tối đa 30 ngày).
3. Giá/quote như F2/F3.
4. Request `scheduled`.
5. Trước giờ 30 phút:
   - Gửi đến tài xế.
6. Nếu không match:
   - Thông báo trước 15 phút; gợi ý đổi giờ/giá.
7. Passenger huỷ trước 30 phút: miễn phí.

## F15. SOS

1. Trong chuyến → SOS.
2. Confirm “Gọi 113 và chia sẻ vị trí?”.
3. Gọi 113.
4. Gửi SMS/link cho emergency contact.
5. Admin live ops nhận alert.
6. Ghi audit.
7. Không chặn chuyến; nhưng ghi nhận.

## F16. Offline / lỗi

- Mất mạng giữa request:
  - Banner “Mất kết nối. Yêu cầu vẫn được lưu.”
  - Retry tự động.
- Mất mạng khi đang chuyến:
  - Cache route + ETA cuối.
  - Không cho hoàn tất nếu chưa đồng bộ? Cho hoàn tất offline, sync sau.
- API lỗi:
  - Error state + “Thử lại”.
- Giá đã đổi do offer hết hạn:
  - Không tự chốt; yêu cầu chọn lại.

## F17. Empty states

- Chưa có chuyến: minh hoạ + “Chưa có chuyến nào. Đặt chuyến đầu tiên nhé.” + CTA.
- Không có offer: “Chưa có tài xế nhận giá này. Thử tăng giá hoặc mở quote.”
- Không có thông báo: “Chưa có thông báo.”
- Không có giao dịch: “Chưa có giao dịch.”
- Không có KYC: CTA xác thực.

## F18. Transition matrix (tóm tắt)

| Từ | Hành động | Đến |
|---|---|---|
| Home | Gửi request | Searching |
| Searching | Offer đầu tiên | Offers |
| Offers | Chọn offer | Driver assigned |
| Driver assigned | Driver đến | Arrived |
| Arrived | Bắt đầu | In progress |
| In progress | Hoàn tất | Completed |
| Completed | Thanh toán | Paid |
| Paid | Đánh giá | Closed |
| Bất kỳ trước start | Huỷ | Cancelled |
| Completed | Tranh chấp | Disputed |
