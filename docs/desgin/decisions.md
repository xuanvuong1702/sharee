# decisions.md — Decision log & giả định

> Mọi thay đổi quyết định phải ghi vào đây. Không sửa lặng lẽ.

## Đã chốt

| # | Quyết định | Lý do | Ngày |
|---|---|---|---|
| D01 | Sản phẩm là chợ chuyến đi thương lượng giá | Yêu cầu chính | 2026-11-19 |
| D02 | Không app-set price/surge | Yêu cầu chính | 2026-11-19 |
| D03 | Passenger chọn tài xế thủ công | Tin cậy, minh bạch | 2026-11-19 |
| D04 | Offer ask 120s, open 180s, counter 90s | Cân bằng chờ/ánh xạ | 2026-11-19 |
| D05 | Max 5 offer active/driver, 20/request | Chống spam | 2026-11-19 |
| D06 | Broadcast 5km mặc định | Mật độ đô thị Việt Nam | 2026-11-19 |
| D07 | Hỗ trợ cash + online escrow | Thị trường Việt Nam | 2026-11-19 |
| D08 | MVP platform fee 0% | Chưa có mô hình doanh thu | 2026-11-19 |
| D09 | Một passenger/chuyến MVP | Giảm phức tạp | 2026-11-19 |
| D10 | Không multi-stop/shared ride MVP | P1/P2 | 2026-11-19 |
| D11 | Bỏ super-app, Green SM teal/3D | Khác sản phẩm/bản quyền | 2026-11-19 |
| D12 | Brand cobalt + amber + mint | Offer/trust/action tách vai trò | 2026-11-19 |
| D13 | Font Be Vietnam Pro | Tiếng Việt tốt, đã bundle | 2026-11-19 |
| D14 | Passenger KYC bắt buộc cho online hạn mức cao | Giảm gian lận | 2026-11-19 |
| D15 | Driver KYC bắt buộc trước online | An toàn | 2026-11-19 |
| D16 | Escrow released khi complete + auto 2h | Cân bằng | 2026-11-19 |
| D17 | Dispute window 24h sau chuyến | Đủ thời gian báo | 2026-11-19 |
| D18 | Chat trước match chỉ template | Chống off-platform | 2026-11-19 |
| D19 | Không hiển thị SĐT đầy đủ | Privacy | 2026-11-19 |
| D20 | Admin live ops + command palette | Vận hành | 2026-11-19 |

## Giả định cần xác nhận

| # | Giả định | Ảnh hưởng nếu sai |
|---|---|---|
| A01 | Platform fee = 0% MVP | Giá/receipt/payout |
| A02 | Không cần hoá đơn VAT ngay | Receipt/legal |
| A03 | Driver có thể huỷ có phạt | Chính sách |
| A04 | Cash được phép toàn quốc | Payments/risk |
| A05 | Passenger không cần KYC cho chuyến giá thấp | Trust |
| A06 | Offer không được tự động nhận | UX |
| A07 | Một tài xế chỉ nhận 1 chuyến active | Dispatch |
| A08 | Không có pool/shared ride | Scope |
| A09 | Admin được xem bằng chứng | Privacy |
| A10 | Ngôn ngữ chỉ tiếng Việt MVP | Localization |

## Câu còn mở

1. Có cần **đặt cọc** cho cash/no-show không?
2. Có cần **bảo hiểm** từng chuyến không?
3. Có cần **hoá đơn VAT** cho doanh nghiệp không?
4. Có cần **call masking** ngay MVP hay P1?
5. Có cần **auto release 2h** hay passenger phải xác nhận?
6. Có cần **giá tham khảo** không? Nếu có, hiển thị thế nào để không thành app-set price?
7. Có cần **KYC hành khách** cho mọi chuyến không?
8. Có cần **nhiều điểm dừng** cho sân bay không?
9. Có cần **xe hợp đồng/doanh nghiệp** không?
10. Có cần **tiếng Anh** ngay không?

## Quy tắc đổi quyết định

1. Đề xuất thay đổi.
2. Ghi lý do + ảnh hưởng.
3. Cập nhật docs liên quan.
4. Chỉ code sau khi docs đồng bộ.
