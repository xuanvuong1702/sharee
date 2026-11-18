# admin.md — Thiết kế admin web

## 1. Mục tiêu

Admin không phải dashboard trang trí. Admin là **live operations + trust + money**.

Ưu tiên:

1. SOS/tranh chấp đang mở.
2. KYC đang chờ.
3. Chuyến bất thường.
4. Thanh toán/escrow.
5. Tăng trưởng (sau).

## 2. Nguyên tắc

- **Command-first:** `Ctrl/Cmd+K` mở command palette.
- **Density:** bảng gọn, 12–13px, row 44–52; tabular numbers.
- **Split view:** list trái, detail phải; không mở modal cho detail.
- **Trạng thái rõ:** chip màu + text; không chỉ màu.
- **Audit:** mọi hành động admin ghi log.
- **Không tự đổi giá** trừ tranh chấp có lý do.
- **PII tối thiểu:** che SĐT/CCCD; chỉ xem tài liệu khi có quyền.

## 3. IA

```text
Login
└─ Shell
   ├─ Dashboard
   ├─ Live ops
   │  ├─ Map
   │  ├─ SOS queue
   │  └─ Trips active
   ├─ KYC
   │  ├─ Queue
   │  └─ Detail
   ├─ Trips
   ├─ Disputes
   ├─ Users
   ├─ Drivers
   ├─ Payments/Escrow
   ├─ Promotions
   ├─ Support
   ├─ Config
   └─ Audit
```

## 4. Dashboard

### Layout

- Top: title + date range + environment badge.
- KPI 4×2:
  - Chuyến hôm nay
  - Tỷ lệ match
  - GMV
  - Escrow đang giữ
  - SOS mở
  - KYC chờ
  - Tranh chấp mở
  - Tài xế online
- Chart:
  - Requests vs matches 24h.
  - Completed/cancelled.
- Queue “Cần xử lý”:
  - SOS (đỏ)
  - Tranh chấp (đỏ)
  - KYC (amber)
- Activity feed.

### Empty/loading

- Skeleton KPI/cards.
- Error card retry.
- Không fake data.

## 5. Live ops

- Full-width map.
- Layers:
  - Active trips (blue lines)
  - Drivers online (mint dots)
  - SOS (red pulse)
  - High-demand zones (P1 heatmap; không surge)
- Left panel:
  - SOS list (ưu tiên)
  - Trips active
  - Filters.
- Click trip → drawer:
  - Passenger/driver.
  - Route.
  - Offer/fare.
  - Timeline.
  - Chat/contact.
  - `Can thiệp` (cancel, refund, contact).
- SOS detail:
  - Vị trí.
  - Trip.
  - Emergency contact.
  - Nút gọi 113/người thân.
  - Log.

## 6. KYC

- Queue columns:
  - User.
  - Loại (passenger/driver).
  - Trạng thái.
  - Tuổi hồ sơ (SLA).
  - Chờ bao lâu.
- Detail drawer:
  - Thông tin pháp lý.
  - Ảnh CCCD/GPLX/xe/selfie.
  - Zoom/rotate.
  - So khớp.
  - Checkbox xác nhận đã xem.
  - Approve/reject (lý do bắt buộc).
  - Ghi chú nội bộ.
- Không cho approve nếu thiếu tài liệu.
- Không cho tự duyệt chính mình.
- Tài liệu tải qua API auth.

## 7. Trips

- Table:
  - Mã, passenger, driver, route, giá, trạng thái, thời gian.
- Filters: trạng thái, ngày, giá, có tranh chấp.
- Detail drawer:
  - Timeline.
  - Offer history (giá ban đầu, counter, giá chốt).
  - Payment/escrow.
  - Chat/evidence (nếu có).
  - Map.
  - Flags.
- Không sửa giá trực tiếp; dùng refund/adjustment có audit.

## 8. Disputes

- Queue: open/investigating/resolved.
- Detail:
  - Booking/trip.
  - Hai bên.
  - Mô tả.
  - Evidence gallery (ảnh/PDF).
  - Escrow status.
  - Timeline.
  - Notes.
  - Quyết định: release/refund/partial.
  - Bắt buộc lý do.
- Không tự xem bằng chứng nếu không được phân quyền.
- Redact PII khi chia sẻ.

## 9. Users / Drivers

- Search theo SĐT/tên/ID.
- Detail:
  - Hồ sơ.
  - KYC.
  - Chuyến.
  - Đánh giá.
  - Tranh chấp.
  - Thiết bị/session.
  - Hành động: khoá, mở, reset.
- Driver detail:
  - Xe.
  - Giấy tờ/hạn.
  - Online.
  - Thu nhập.
  - Tỷ lệ huỷ.
  - Offer stats.

## 10. Payments / Escrow

- Tổng quan:
  - Đang giữ.
  - Đã release.
  - Refund.
  - Failed.
- Table giao dịch.
- Detail:
  - Trip.
  - Phương thức.
  - Provider ref.
  - Ledger entries.
  - Trạng thái.
- Refund thủ công có 2 bước + lý do + audit.

## 11. Promotions

- Campaign list.
- Tạo mã:
  - Loại (fixed/percent).
  - Điều kiện.
  - Budget.
  - Thời gian.
  - Service.
- Không cho promo che CTA.
- Không tự động giảm giá chuyến.

## 12. Support

- Ticket queue.
- Detail:
  - User.
  - Trip.
  - Chat.
  - Canned replies.
  - Escalate.
- Không xem full PII nếu không cần.

## 13. Config

- Offer validity.
- Broadcast radius.
- Max offers.
- Cancellation policy.
- Platform fee.
- Payment methods.
- Safety/SOS.
- Feature flags.
- Không cho sửa nếu không có audit.

## 14. Audit

- Ai, làm gì, khi nào, target, before/after.
- Filter.
- Export.
- Không xoá log.

## 15. Design conventions

- Sidebar ink; active teal indicator.
- Font Be Vietnam Pro.
- Radius 16–20.
- Table header uppercase 10px.
- Row hover surface.
- Drawer 520–720px.
- Command palette.
- Keyboard:
  - `Cmd/Ctrl+K`: palette.
  - `Esc`: close.
  - `J/K`: next/prev row (P1).
- Empty states.
- Error states.
- Loading skeleton.
- Dark mode P1.

## 16. Admin accessibility

- Focus ring 2px primary.
- Table có caption/aria.
- Icon buttons có label.
- Contrast.
- Không chỉ màu cho status.
- Keyboard đầy đủ.
- Zoom 200%.
