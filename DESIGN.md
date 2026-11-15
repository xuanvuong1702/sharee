# Sharee — Design System

## Định hướng

**Trusted travel + warm fintech + Vietnamese editorial**

Tham chiếu chính:

- **BlaBlaCar** — luồng tìm chuyến, hồ sơ tài xế, đặt ghế, niềm tin.
- **Bolt** — bản đồ, bottom sheet, tracking.
- **Airbnb** — hình ảnh, cảm xúc, review.
- **Linear** — admin web, mật độ dữ liệu, drawer.
- **Revolut / Wise** — thanh toán, escrow, trạng thái giao dịch.

Không dùng neon crypto, gradient tím AI hoặc glassmorphism quá đà.

## Typography

- **Be Vietnam Pro** cho toàn bộ app/web/admin.
- Display: 800, tracking âm nhẹ.
- Body: 15/22.
- Caption: 11–12, muted.
- Số tiền/ETA dùng tabular numbers khi hiển thị dạng bảng.

Font được bundle tại:

- `apps/mobile/assets/fonts`
- `apps/web/public/fonts`
- `apps/admin/public/fonts`

## Palette

| Token | Giá trị | Dùng cho |
|---|---|---|
| Ink | `#071A33` | Heading, sidebar, hero |
| Primary | `#1F5EFF` | CTA, active, link |
| Primary dark | `#1747CC` | Gradient CTA |
| Primary soft | `#EBF0FF` | Selected, badge |
| Mint | `#00C2A8` | Trust, success |
| Success | `#0FA968` | Escrow an toàn, hoàn tất |
| Sand | `#F6F1E7` | Nền ấm |
| Cloud | `#F6F8FB` | Nền chính |
| Line | `#E4EAF3` | Border |
| Muted | `#64748B` | Metadata |
| Warning | `#B45309` | Chờ xử lý |
| Danger | `#E5484D` | Từ chối, huỷ |

## Shape & spacing

- Card: radius **24px**.
- Input: radius **14px**.
- Button: radius **16px**, cao 54px.
- Pill: radius **999px**.
- Page padding mobile: 16–20px; web: 20–32px.
- Grid 8pt.
- Shadow card: `0 12px 34px rgba(7,26,51,0.07)`.

## Component chính

- `RouteTimeline` — điểm đón/trả dạng đường nối.
- `DriverTrustCard` — avatar, sao, tỷ lệ hoàn thành, KYC.
- `SeatPicker` — chọn ghế trực quan.
- `EscrowBadge` — tiền đang được giữ.
- `PaymentMethodCard` — ngân hàng, ví, tiền mặt.
- `ReputationCard` — điểm, hạng, huy hiệu.
- `EvidenceGallery` — bằng chứng khiếu nại.
- `StatusTimeline` — trạng thái hồ sơ/tranh chấp.
- `SkeletonCard` — loading.
- Admin: `Kpi`, `QueueItem`, `ActivityRow`, `ReviewDrawer`.

## Nguyên tắc UI

1. Map/route là trung tâm ở home và tracking.
2. Trust xuất hiện gần quyết định: KYC cạnh tài xế, escrow cạnh giá.
3. Một màn hình chỉ 1 CTA chính.
4. Dùng ảnh thật/ảnh sản phẩm thay illustration chung.
5. Chuyển động 180–280ms, có mục đích.
6. Empty state có hành động tiếp theo.
7. Microcopy bình tĩnh, nói lợi ích thay vì kỹ thuật.

## Trạng thái đã áp dụng

- Flutter: theme Be Vietnam Pro, palette mới, card/button/input mới, login trust chips, home “An tâm mỗi chuyến”, escrow note trong trip detail.
- Next web: hero editorial, trust stats, KYC/escrow/appeal/reputation features, font local.
- Admin: sidebar ink, KPI escrow/khiếu nại, queue items, health card, audit activity, font Be Vietnam Pro.
