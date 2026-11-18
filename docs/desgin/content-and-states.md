# content-and-states.md — Voice, trạng thái, accessibility

## 1. Giọng văn

- Xưng **“bạn”**, gọi tên khi chào.
- Ngắn, rõ, bình tĩnh; không lóng, không emoji trong tình huống tiền/an toàn.
- Nói lợi ích và hậu quả cụ thể.
- Không đổ lỗi người dùng.
- Không hứa “giá rẻ nhất”, “chắc chắn có tài xế”.

### Mẫu

| Tình huống | Copy |
|---|---|
| Home | “Bạn muốn đi đâu?” |
| Giá | “Giá bạn muốn trả” |
| Helper giá | “Giá cuối do bạn và tài xế thống nhất.” |
| Mở quote | “Để tài xế báo giá” |
| Đang tìm | “Đang tìm tài xế gần bạn” |
| 0 offer | “Chưa có tài xế nhận giá này. Thử tăng giá hoặc mở quote.” |
| Offer mới | “Có tài xế gửi giá” |
| Counter | “Tài xế đề nghị thêm 20.000đ” |
| Chốt | “Chốt chuyến với Minh?” |
| Offer hết hạn | “Giá này đã hết hạn. Chọn giá khác nhé.” |
| Driver đến | “Tài xế đã đến điểm hẹn” |
| Đang chạy | “Chuyến đang diễn ra” |
| Hoàn tất | “Chuyến đã hoàn tất” |
| Escrow | “Tiền đang được giữ an toàn” |
| Giải ngân | “Đã chuyển tiền cho tài xế” |
| Cash | “Bạn đã trả tiền mặt?” |
| Huỷ | “Huỷ chuyến?” + lý do + phí |
| Không có chuyến | “Chưa có chuyến nào. Đặt chuyến đầu tiên nhé.” |
| Lỗi mạng | “Không thể kết nối. Kiểm tra mạng rồi thử lại nhé.” |
| KYC chờ | “Hồ sơ đang được duyệt. Bạn sẽ nhận thông báo khi xong.” |
| KYC từ chối | “Hồ sơ chưa được duyệt. Lý do: …” |
| SOS | “Gọi 113 và chia sẻ vị trí?” |
| Tranh chấp | “Điều gì đã xảy ra?” |

## 2. Định dạng

| Loại | Quy tắc | Ví dụ |
|---|---|---|
| Tiền | dấu chấm nghìn + `đ` | `120.000đ` |
| Giá counter | dấu `+`/`−` | `+20.000đ` |
| Ngày | `dd/MM` cùng năm | `19/11` |
| Giờ | `HH:mm` | `21:30` |
| Thời lượng | số + `phút` | `21 phút` |
| Khoảng cách | `1,2 km` | `350 m` |
| SĐT | che giữa | `+84 91 *** 678` |
| Biển số | đủ khi đã chốt | `30A-123.45` |
| Mã chuyến | 8 ký tự | `SH-A1B2C3D4` |

## 3. State machine — Offer

| State | UI | Người dùng làm gì |
|---|---|---|
| `sent` | “Đã gửi giá” | chờ |
| `viewed` | “Đã xem” | chờ |
| `countered` | “Đề nghị giá” | accept/decline/counter |
| `accepted` | “Đã chốt” | sang trip |
| `declined` | “Đã từ chối” | tìm tài xế khác |
| `expired` | “Hết hạn” | gửi lại/tăng giá |
| `withdrawn` | “Tài xế đã rút” | chọn offer khác |

## 4. State machine — Trip

| State | Copy | Hành động |
|---|---|---|
| `driver_assigned` | “Tài xế đang đến” | theo dõi/huỷ |
| `driver_arriving` | “Còn 4 phút” | chat/gọi |
| `driver_arrived` | “Tài xế đã đến” | lên xe |
| `in_progress` | “Đang di chuyển” | share/SOS |
| `completed` | “Chuyến đã hoàn tất” | thanh toán/đánh giá |
| `cancelled` | “Chuyến đã huỷ” | lý do/hoàn tiền |
| `disputed` | “Đang xử lý tranh chấp” | xem bằng chứng |

## 5. State machine — Payment

| State | Copy |
|---|---|
| `pending` | “Chờ thanh toán” |
| `authorized` | “Tiền đang được giữ” |
| `captured` | “Đã thanh toán” |
| `released` | “Đã chuyển cho tài xế” |
| `refunded` | “Đã hoàn tiền” |
| `failed` | “Thanh toán thất bại” |
| `cash_due` | “Thanh toán tiền mặt khi kết thúc” |
| `cash_collected` | “Đã thu tiền mặt” |
| `disputed` | “Tiền đang bị giữ do tranh chấp” |

## 6. Loading / empty / error / offline

### Loading

- Skeleton đúng kích thước.
- Button loading giữ nguyên width.
- Quá 8s: “Đang mất nhiều thời gian hơn dự kiến.”
- Không spinner toàn màn nếu có layout.

### Empty

- Illustration line/gradient.
- 1–2 câu.
- CTA nếu có hành động.
- Không đổ lỗi.

### Error

- Nói nguyên nhân + cách xử lý.
- Nút `Thử lại`.
- Không hiển thị stack trace/mã lỗi kỹ thuật.
- Log mã trace ẩn.

### Offline

- Banner mỏng “Không có kết nối”.
- Cache nội dung.
- Disable action cần mạng.
- Request đang gửi: queue + retry.

## 7. Accessibility

- Contrast ≥4.5:1; large ≥3:1.
- Touch ≥44 iOS / 48 Android.
- Dynamic Type 130%.
- Screen reader label cho icon-only, map marker, countdown.
- Không chỉ dùng màu: status có text/icon.
- Focus order.
- Reduce Motion: tắt shimmer/auto-play/map animation.
- Reduce Transparency: thay glass bằng surface.
- Tiếng Việt có dấu; line-height ≥1.3.
- Countdown đọc “Còn 2 phút 14 giây”, không chỉ “2:14”.
- Map có alternative text/list cho screen reader.

## 8. Anti-patterns

1. App tự đặt giá/surge.
2. Giấu phí.
3. Hiển thị giá “từ ...” như giá cố định.
4. Hơn 1 primary CTA.
5. Banner khuyến mãi che CTA đặt chuyến.
6. Icon-only không label.
7. Modal chồng modal.
8. Bottom sheet chồng bottom sheet.
9. Huỷ không confirm/không nói phí.
10. Hiện đầy đủ SĐT/CCCD/thẻ.
11. Countdown không rõ khi hết hạn.
12. Auto-accept offer thay người dùng.
13. Chat trước match không giới hạn.
14. Dùng logo/mascot/3D asset cụ thể của Green SM.
15. Hardcode token.
16. Màn hình trống không CTA.
17. Loading khác kích thước nội dung.
18. Dùng ảnh stock nước ngoài cho địa điểm Việt Nam.
19. Chữ <12pt.
20. Thêm đồ ăn/giao hàng vào app.

## 9. Microcopy cho lỗi giá

| Case | Copy |
|---|---|
| Giá trống | “Nhập giá bạn muốn trả.” |
| Giá 0 | “Giá phải lớn hơn 0.” |
| Giá quá cao | “Giá tối đa 10.000.000đ.” |
| Giá quá thấp | “Giá này rất thấp. Tài xế có thể không nhận.” (warning, không chặn) |
| Counter không đổi | “Giá mới phải khác giá hiện tại.” |
| Offer hết hạn | “Giá đã hết hạn. Gửi lại hoặc chọn offer khác.” |
| Offer bị rút | “Tài xế đã rút giá.” |
| Không đủ tiền | “Số dư không đủ. Chọn phương thức khác hoặc nạp thêm.” |

## 10. Microcopy an toàn

- “Chia sẻ chuyến để người thân biết bạn đang đi đâu.”
- “Chỉ lên xe khi biển số trùng với app.”
- “Nếu cảm thấy không an toàn, gọi 113.”
- “Số điện thoại được bảo vệ. Liên hệ qua app.”
- “Tài xế đã được xác thực”. Không nói “tài xế an toàn 100%”.

## 11. Localization

- Việt mặc định; English P1.
- Không đặt chữ trong ảnh.
- Label dài 1.5x không vỡ.
- Tiền/ngày theo locale.
- Tên riêng/địa danh giữ nguyên.

## 12. Checklist content

- [ ] Có label ngoài input.
- [ ] Có helper/error.
- [ ] Có empty/loading/error/offline.
- [ ] Có countdown copy.
- [ ] Có huỷ/hoàn tiền copy.
- [ ] Có escrow copy.
- [ ] Có accessibility label.
- [ ] Không dùng emoji chức năng.
- [ ] Không chữ <12pt.
- [ ] Không phí ẩn.
