# video-analysis.md — Phân tích 4 video Green SM

> Nguồn: 4 screen recording trong `screenshot/`. Phân tích frame ở 0.35–0.7s, có cắt riêng đoạn chuyển tab.
> Mục tiêu: tách **layout / motion / interaction** để tái hiện gần nhất; không sao chép asset/logo/mascot.

## 1. Tổng quan video

| Video | Dài | Nội dung | Bài học chính |
|---|---|---|---|
| `05-43-18` | 6.4s | Home cuộn lên/xuống | Search cuộn cùng nội dung; card/grid; tab bar nổi |
| `05-43-35` | 16.8s | Home → Hoạt động → Thông báo → Tài khoản | Tab switch crossfade; active glow; empty state |
| `05-44-03` | 6.1s | Thanh toán + app switcher | List row, phương thức, masked number |
| `05-44-21` | 17.2s | Search địa điểm + bàn phím + filter | Full-screen search; keyboard; suggestion list |

## 2. Video 1 — Home cuộn

### Quan sát

- Search bar nằm trong vùng nội dung, **cuộn đi** khi kéo xuống; không phải sticky cố định.
- Hero card và grid dịch vụ trượt dưới search.
- Tab bar vẫn nổi ở đáy trong video gốc; yêu cầu sản phẩm của Sharee là **ẩn khi cuộn xuống** (đã triển khai riêng).
- Card dịch vụ có 3D icon, nền trắng, bán kính lớn.
- Khoảng cách giữa các section ~20–24px.

### Motion

- Cuộn là scroll native, không parallax.
- Card không có hiệu ứng nổi khi cuộn.
- 3D icon gần như tĩnh, không xoay.

## 3. Video 2 — Tab switch

### Quan sát frame 3.0–3.8s

| Thời điểm | Trạng thái |
|---|---|
| 3.40s | Home còn nguyên |
| 3.50s | Nội dung Hoạt động hiện **mờ** (opacity thấp), filter/empty state đã có |
| 3.60s | Nội dung Hoạt động rõ hoàn toàn |
| 3.70–3.80s | Ổn định |

Kết luận:

- Chuyển tab dùng **crossfade/fade-in ~150–250ms**, không trượt ngang.
- Nội dung mới hiện dần; tab bar giữ nguyên.
- Active indicator đổi màu/glow; không có slide pill rõ ràng.

### Đã áp dụng

- `_AnimatedTabStack`: giữ state từng tab, `AnimatedOpacity` 200ms, `easeOut`.
- Inactive tab bị `IgnorePointer` + `ExcludeSemantics`.
- Reduce Motion: đổi tức thì.
- Tab bar active pill: 250ms.

## 4. Video 3 — Thanh toán

### Quan sát

- Danh sách nhóm phương thức, logo nhỏ, số thẻ che, dấu `>`.
- Nút/row mở màn chi tiết; không có animation đặc biệt.
- CTA teal đậm, chữ trắng.
- Nền trắng, divider mảnh.

### Bài học

- Row height ~52–56; icon 24; label 14–15.
- Thông tin nhạy cảm che bằng `••••`.
- Không dùng card lồng card.

## 5. Video 4 — Search địa điểm

### Timeline

| Thời điểm | Trạng thái |
|---|---|
| 1.4s | Home |
| 2.1s | Search full-screen, header địa điểm, field, suggestion list |
| 2.8–3.5s | Keyboard trượt lên; suggestion list co lại |
| 4.2–7.0s | Gõ tìm kiếm, list cập nhật |
| 11.2–13.3s | Filter sheet “Tìm kiếm nâng cao” |
| 16.1s | Quay lại Home |

### Motion

- Search mở bằng **push route** (không phải bottom sheet), header + field xuất hiện cùng keyboard.
- Keyboard trượt lên theo hệ điều hành; list scroll độc lập.
- Chọn địa điểm → quay lại map/home.
- Không có tab bar trong search.

### Đã áp dụng

- `LocationPickerScreen` full-screen.
- Search field auto focus; gợi ý debounce 350ms.
- Keyboard native.
- Chọn điểm → pop về map; map fit.
- Chưa có filter sheet nâng cao.

## 6. Motion spec rút ra

| Interaction | Green SM quan sát | Sharee |
|---|---|---|
| Tab content | Fade 150–250ms | 200ms easeOut |
| Tab active | Glow/scale nhẹ | Pill + glow 250ms |
| Tab bar hide | (yêu cầu) trượt/fade | 220ms slide + 160ms fade |
| Search open | Push, ~250ms | 320ms fade/slide |
| Keyboard | Native | Native |
| Card press | Giảm nhẹ | Scale .98 + haptic |
| 3D icon | Tĩnh/float rất nhẹ | Float ±2px, 3.2s |
| List load | Skeleton/empty | Skeleton/empty |

## 7. Có thể “giống hệt” không?

### Có thể làm rất gần

- Cấu trúc Home: search, hero card, grid, promo strip.
- Tab bar kính, icon, active glow.
- Crossfade tab, scroll hide.
- Full-screen search + keyboard.
- Card radius, spacing, typography, pastel palette.
- 3D icon style (bộ riêng).

### Không nên/không thể copy 1:1

- Logo, mascot, bộ 3D, ảnh banner, illustration của Green SM.
- Chính xác từng pixel vì khác font/asset/device.
- Toàn bộ IA super-app (đồ ăn, giao hàng, trophy).
- Logic giá cố định của Green SM (Sharee không đặt giá).

> **Kết luận:** có thể đạt 85–95% cảm giác giao diện/animation nếu có bộ asset 3D riêng; không nên quảng cáo là “giống hệt” vì lý do bản quyền và khác biệt sản phẩm.

## 8. Việc còn thiếu để sát hơn

1. Bộ 3D icon riêng (hiện dùng Fluent Emoji).
2. Search collapsing/sticky theo scroll như bản gốc.
3. Filter sheet “Tìm kiếm nâng cao”.
4. Promo carousel/banner và asset riêng.
5. Icon tab bar đúng bộ Green SM (không copy; thiết kế lại).
6. Page transition search 250ms thay vì 320ms.
7. Kiểm tra animation trên iPhone thật (video 60fps).
