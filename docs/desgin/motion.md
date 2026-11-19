# motion.md — Phân tích animation Green SM và đặc tả cho Sharee

> Nguồn: 18 screenshot + 4 screen recording (6.4s, 16.8s, 6.1s, 17.2s) tại `screenshot/`.
> Mục tiêu: lấy **nhịp điệu, cảm giác mềm, độ nổi** của Green SM; không copy asset/mascot/logo.

## 1. Điều quan sát được từ video

| Hành vi | Quan sát | Hàm ý |
|---|---|---|
| Cuộn Home | Nội dung trượt dưới search bar; search bar giữ vị trí; tab bar vẫn nổi | Header/search là lớp nổi, content là lớp dưới |
| Chuyển tab | Nền teal của tab active trượt/nhấp nháy nhẹ; icon đổi màu | Indicator chuyển động, không đổi cứng |
| Mở search | Search mở toàn màn, keyboard trượt lên, gợi ý hiện dần | Transition ngắn, tập trung |
| Bottom sheet | Sheet trượt lên mượt, không giật | Spring/ease-out, 260–300ms |
| Card press | Card co nhẹ, không đổi layout | Scale .98 + haptic |
| 3D icon | Icon đứng yên, không xoay liên tục; có chiều sâu | Tĩnh là chính; float rất nhẹ nếu có |
| Page transition | Chuyển màn mềm, không trượt ngang gắt | Fade-through/slide nhẹ |
| Tab bar | Viên thuốc kính, active phát sáng, nút tròn riêng bên phải | Floating glass + action tách |

## 2. Nguyên tắc animation

1. **Mềm, ngắn, có mục đích.** 150–300ms; không animation dài hơn 500ms trừ success/map.
2. **Không chặn thao tác.** Animation không làm chậm đặt chuyến/chọn offer.
3. **Ưu tiên transform/opacity.** Không animate layout nặng.
4. **Tôn trọng Reduce Motion.** Tắt float, shimmer, carousel, map zoom.
5. **Không auto-play nội dung quảng cáo** quá 4s; dừng khi chạm.
6. **Phản hồi ngay:** press feedback trước khi network trả về.

## 3. Timing & easing

| Token | Giá trị | Dùng |
|---|---|---|
| `motion.fast` | 150ms | Press, chip, icon |
| `motion.base` | 220ms | Card, fade, search |
| `motion.sheet` | 280ms | Bottom sheet |
| `motion.slow` | 400ms | Page transition, success |
| `motion.map` | 500ms | Camera |
| `easing.standard` | `cubic-bezier(0.2, 0, 0, 1)` | Hầu hết |
| `easing.decelerate` | `cubic-bezier(0, 0, 0, 1)` | Vào màn |
| `easing.spring` | `cubic-bezier(0.34, 1.56, 0.64, 1)` | Tab/indicator |

## 4. Đặc tả từng interaction

### 4.1 FloatingTabBar

- Container pill glass, blur 20.
- Active indicator: pill teal nhạt, di chuyển giữa các tab.
- Thời gian: 250ms, `easing.spring`.
- Icon active: scale 1.08, màu `primaryDeep`; inactive `muted`.
- Label: ẩn mặc định; hiện khi Dynamic Type/accessibility.
- Nút tròn bên phải (Đặt chuyến): press scale .94, shadow giảm.
- Badge chưa đọc: pop 180ms.

### 4.2 SearchBar

- Khi cuộn > 8px:
  - Nền chuyển từ trắng đặc sang glass.
  - Viền/shadow tăng nhẹ.
  - 180ms.
- Tap:
  - Search screen mở bằng fade + slide lên 12px, 220ms.
  - Keyboard trượt lên theo hệ điều hành.
- Gợi ý: stagger 30ms/item, tối đa 5 item.

### 4.3 Card press

- Scale 0.98, 120ms.
- Haptic selection.
- Shadow giảm.
- Không đổi màu mạnh.

### 4.4 Hero service card

- 3D icon float ±2px, 3.2s loop; chỉ khi Reduce Motion off.
- Press: icon scale 1.03, card .99.
- Không auto-rotate.

### 4.5 Bottom sheet

- `showModalBottomSheet`/custom: 280ms `decelerate`.
- Drag handle.
- Backdrop fade 180ms.
- Không mở sheet mới khi sheet cũ chưa đóng.

### 4.6 Page transition

- Fade-through 220ms + 8px slide.
- Hero image shared element nếu có.
- Back dùng reverse.

### 4.7 Carousel/banner

- Auto 4s.
- Pause khi chạm/scroll.
- Dots transition 200ms.
- Reduce Motion: tắt auto.

### 4.8 Skeleton

- Shimmer 1.2s, gradient nhẹ.
- Cùng kích thước nội dung thật.
- Reduce Motion: static.

### 4.9 Success

- Check icon scale 0.8→1.0, 400ms spring.
- Không confetti toàn màn; tối đa 600ms.
- Receipt slide-up 300ms.

### 4.10 Map

- Camera move 500ms.
- Marker pulse 1.5s loop (chỉ driver/radar).
- Route draw 400ms.
- Không animate map khi Reduce Motion; nhảy trực tiếp.

### 4.11 Tab content

- Giữ scroll position.
- Nếu tab mới: fade 150ms.
- Không reload toàn bộ nếu có cache.

## 5. 3D asset strategy

- Không dùng asset Green SM.
- Dùng bộ 3D icon bản quyền mở (ví dụ Fluent Emoji 3D — MIT) hoặc commission bộ riêng.
- Style: pastel, mềm, cùng ánh sáng, cùng góc nhìn.
- Kích thước: 40/48/64/96.
- Nền: gradient teal nhạt hoặc trắng.
- Không trộn 3D với line icon trong cùng nhóm chức năng.
- Quy ước:
  - 3D: dịch vụ/chính (Đặt xe, Đặt lịch, An toàn).
  - Outline: cài đặt/danh sách.
  - Flat màu: tiện ích phụ.

## 6. Accessibility

- Reduce Motion: tắt float, carousel, shimmer, map camera.
- Reduce Transparency: glass → surface đặc.
- Không animation chớp >3Hz.
- Không chỉ dựa vào animation để truyền đạt trạng thái.
- Countdown có text.
- Focus ring 2px.

## 4.12 Bottom tab bar — ẩn khi cuộn xuống, hiện khi cuộn lên

### Hành vi

- Người dùng vuốt nội dung **xuống** (scroll down) → tab bar trượt xuống khỏi màn hình và mờ dần.
- Người dùng vuốt **lên** (scroll up) → tab bar trượt lên trở lại.
- Ở đầu danh sách → luôn hiện.
- Đổi tab / mở màn mới → hiện.
- Kéo refresh ở đầu danh sách → không ẩn.

### Ngưỡng

| Thông số | Giá trị |
|---|---|
| Delta tích luỹ để ẩn | > 10px |
| Delta tích luỹ để hiện | < −6px |
| Bỏ qua jitter | < 6px |
| Trục | Chỉ vertical |
| Depth | Chỉ scroll ngoài cùng (depth 0) |
| Thời gian trượt | 220ms |
| Thời gian mờ | 160ms |
| Easing | `easeOutCubic` / `easeOut` |
| Khoảng trượt | 125% chiều cao tab bar |

### Cảm giác

- Tab bar **trượt xuống** thay vì biến mất đột ngột.
- Không thay đổi layout của nội dung (dùng `extendBody`, overlay).
- Không rung/không haptic khi ẩn/hiện.
- Khi hiện lại, không bounce quá đà; chỉ trượt lên dứt khoát.
- Nội dung vẫn cuộn mượt; không rebuild toàn màn.

### Edge cases

- Horizontal carousel: bỏ qua.
- Nested scroll trong sheet: bỏ qua (depth > 0).
- Pull-to-refresh: giữ tab bar.
- Danh sách ngắn không scroll: tab bar luôn hiện.
- Keyboard mở: tab bar có thể bị che; không xử lý đặc biệt.
- Reduce Motion: đổi trạng thái ngay, không trượt/fade.
- Screen reader: ẩn khỏi semantics khi tab bar đã ẩn.

### Implementation contract

- `HomeShell` bọc `NotificationListener<ScrollNotification>`.
- `_navVisible` điều khiển `AnimatedSlide` + `AnimatedOpacity`.
- `IgnorePointer` + `ExcludeSemantics` khi ẩn.
- `_select()` reset `_navVisible = true`.
- Không dùng `BottomNavigationBar` mặc định vì cần animation tùy biến.

## 7. Checklist motion

- [ ] Tab indicator 250ms, spring.
- [ ] Press scale .98 + haptic.
- [ ] Bottom sheet 280ms.
- [ ] Search glass 180ms.
- [ ] 3D float chỉ decorative.
- [ ] Skeleton cùng size.
- [ ] Reduce Motion.
- [ ] Không auto-play quá 4s.
- [ ] Không animation chặn CTA.
- [ ] 60fps trên máy tầm trung.
