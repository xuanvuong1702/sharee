# components.md — Component library

> Token path → `tokens.json`. Mọi component có: anatomy, variants, sizes, states, accessibility, do/don't.

## 1. AppShell / Map screen

**Dùng:** Home, tracking, driver radar.

- Full-bleed map.
- Top overlay: safe area + header.
- Bottom sheet: `DraggableScrollableSheet` 0.28 → 0.9.
- Trip banner nếu có active trip.
- Không đặt content quan trọng dưới tab bar.

**States:** map loading, location denied, offline, GPS weak.

## 2. TopBar

| Variant | Dùng |
|---|---|
| A. Map overlay | Home/driver radar: avatar, greeting, action icons |
| B. Back + title | Màn con |
| C. Large title | History/inbox |
| D. Sheet header | Bottom sheet: drag handle + title + close |

- Back: arrow 24, touch 44; trên ảnh dùng nền tròn trắng 40.
- Không trộn kiểu back.

## 3. SearchField

- Cao 52, pill, icon search, placeholder.
- States: default, focus, filled, loading (đang lấy vị trí), error.
- Trên map: floating, shadow.
- Tap → full-screen search (P02/P03).
- Không dùng làm label.

## 4. LocationPicker

- Hai dòng: pickup (dot mint) + destination (dot amber).
- Tap từng dòng.
- Nút swap.
- Saved/recent list.
- Bản đồ chọn pin.
- “Vị trí của tôi” button.

## 5. FareInput

- Label “Giá bạn muốn trả”.
- Số tiền lớn 32–36, tabular.
- Stepper −10.000 / +10.000.
- Preset chips (nếu có lịch sử) nhưng không auto.
- Toggle “Để tài xế báo giá”.
- Helper: “Giá cuối do bạn và tài xế thống nhất.”
- Error: min/max.
- Không hiển thị “giá đề xuất” như bắt buộc.

## 6. SchedulePicker

- Segmented: Bây giờ / Đặt lịch.
- DatePicker, TimePicker.
- Min 30 phút, max 30 ngày.
- Hiển thị timezone.

## 7. VehicleClassSelector

- Cards/chips: Xe máy, 4 chỗ, 7 chỗ, xe sang (P1).
- Icon line, label, mô tả ghế.
- Selected viền primary.
- Không hiển thị giá app-set.

## 8. PrimaryButton / SecondaryButton / TextButton

- Cao 52; radius 16; label 15/600.
- Primary teal đậm; secondary surface + border; destructive text danger.
- States: default, pressed (scale .98), disabled, loading (spinner, giữ size).
- 1 primary/vùng.

## 9. DriverOfferCard

**Mục đích:** so sánh và chọn tài xế.

Anatomy:

```text
[Avatar] Tên · 4.9★ · 128 chuyến      Giá 120.000đ
         KYC ✓ · Toyota Vios · 30A-123.45
         Đến sau 4 phút                 [Chọn]
```

Variants:

- `ask-accept`: giá = giá passenger.
- `counter`: giá + chênh lệch amber.
- `quote`: giá tài xế.
- `expired`: mờ, label.
- `selected`: viền primary, tick.

States: default, pressed, selected, expired, loading (skeleton).

Rules:

- Giá luôn nổi bật hơn tên.
- Chênh lệch phải hiển thị nếu counter.
- Không giấu ETA/rating.
- Không cho chọn offer hết hạn.

## 10. OfferList / NegotiationSheet

- Header: route, giá passenger, countdown, sort.
- List card.
- Pull-to-refresh.
- Live update.
- Footer: “Giá đã bao gồm...”nếu có.
- Empty/loading/error.
- Countdown đổi màu khi <30s.

## 11. CounterOfferSheet

- Giá hiện tại.
- Input giá mới.
- Chênh lệch realtime.
- Note (optional).
- CTA `Gửi giá`.
- Helper “Tài xế có 90 giây để phản hồi.”
- Không cho gửi nếu không đổi.

## 12. DriverTrustCard

- Avatar 48.
- Tên + badge KYC.
- Sao + số chuyến + tỷ lệ hoàn thành.
- Xe + biển số.
- `Xem hồ sơ`.
- Không hiển thị SĐT.

## 13. TripStatusTimeline

States:

```text
Đã nhận → Đang đến → Đã đến → Đang di chuyển → Hoàn tất
```

- Dot active mint, done muted, upcoming line.
- ETA.
- Error branch (cancelled/disputed) rõ.

## 14. MapMarker

- Pickup: mint pin.
- Destination: amber pin.
- Driver: car icon + heading.
- Cluster (P1).
- Tap → tooltip.

## 15. SafetyToolbar

- Share trip, SOS, call, chat.
- SOS đỏ, confirm.
- Share dùng native share sheet.
- Accessibility labels.

## 16. PaymentMethodCard

- Logo 24 + tên + số che + check.
- Variants: wallet, bank, card, cash.
- Default badge.
- Disabled.
- Security note.
- Không hiển thị full số.

## 17. FareBreakdown

- Cước.
- Phụ phí (nếu có).
- Phí nền tảng.
- Tip.
- Tổng.
- Dòng “Giá đã chốt” rõ.
- Không thêm dòng ẩn.

## 18. EscrowStrip

- Icon lock + “Tiền đang được giữ”.
- Số tiền.
- Trạng thái: held/released/refunded/disputed.
- Link “Tìm hiểu”.
- Không dùng màu cam cho trạng thái an toàn.

## 19. ReceiptTicket

- Ticket motif, dashed divider.
- Route, time, fare, payment, code.
- QR (signed token).
- Download/share.
- Không chứa PII đầy đủ.

## 20. RatingSheet

- 5 sao.
- Tags.
- Comment.
- Tip.
- Skip.
- Error/loading.

## 21. EmptyState

- 3D pastel/asset riêng hoặc line illustration; không copy asset Green SM.
- Title + body + optional CTA.
- Dùng cho: no trips, no offers, no messages, no earnings.

## 22. Skeleton

- Cùng kích thước card thật.
- Shimmer 1.4s; Reduce Motion → static.
- Không spinner toàn màn nếu có layout.

## 23. DriverRequestCard

- Pickup distance + ETA.
- Dropoff.
- Giá passenger.
- Note icon.
- Countdown.
- CTA `Xem`.

## 24. OnlineToggle

- Switch + label “Đang nhận chuyến”.
- Offline → map dim, CTA online.
- Nếu KYC thiếu → disabled + lý do.

## 25. EarningsCard

- Today.
- Week.
- Balance.
- Withdraw CTA.
- Chart (P1).

## 26. WithdrawSheet

- Số dư.
- Số tiền.
- Bank account.
- Fee.
- Confirm.
- OTP (P1).

## 27. AdminQueueTable

- Header, filter, bulk action.
- Row: id, user, status, amount, age.
- Drawer detail.
- Empty/loading/error.
- Keyboard navigation.

## 28. AdminLiveMap

- Map + active trips + SOS pulses.
- Filter driver status.
- Click trip → drawer.
- Không auto-refresh quá 5s.

## 29. StatusChip

- `searching`: amber.
- `offers`: blue.
- `matched`: mint.
- `in_progress`: blue.
- `completed`: mint.
- `cancelled`: gray/red.
- `disputed`: red.
- Luôn có text, không chỉ màu.

## 30. Tooltip / Coachmark

- Chỉ dùng onboarding; tối đa 1/lần.
- Không che CTA.

## 31. FloatingTabBar (Green SM style)

**Mục đích:** điều hướng chính, tạo cảm giác nổi và nhẹ.

Anatomy:

```text
┌──────────────────────────────┐   ╭────╮
│  ⌂     ◷     ✉     ☺        │   │ +  │
└──────────────────────────────┘   ╰────╯
     glass pill, 4 icons            CTA tròn
```

- Cao 64; pill; blur 20; nền `overlay.glass`; viền trắng 0.7.
- 4 icon 24; active icon `primaryDeep`, indicator pill `primaryTint` + glow.
- Indicator di chuyển 250ms spring.
- Nút tròn 58, gradient teal, icon `+`/car; tách 10px; shadow.
- Label ẩn; accessibility label + tooltip.
- Badge chưa đọc: dot đỏ.
- Ẩn ở màn con/CTA dính đáy.
- Không thêm tab thứ 5 vào pill.

## 32. ServiceHeroCard (3D)

- 2 card/hàng; cao 100; radius 24.
- Nền gradient teal pastel (Đặt chuyến) / vàng pastel (Đặt lịch).
- Tiêu đề 18/700; subtitle 12.
- 3D icon 64 ở phải, có thể tràn nhẹ.
- Press scale .98; icon float ±2px (reduce motion off).
- Không quá 2 hero card trên Home.

## 33. ServiceTile (3D)

- Lưới 4 cột; ô 84×92.
- Nền trắng; radius 18; border line.
- 3D icon 40–48; label 12/600, tối đa 2 dòng.
- Badge góc trên phải (`-25%`, `Mới`) dùng promo.
- Press scale .98.
- Không dùng 3D icon cho cài đặt/danh sách.

## 34. ProfileHero

- Nền gradient teal nhạt → bg.
- Avatar 72 (3D/ảnh), badge KYC.
- Tên 22/800; SĐT che; chip hạng.
- Stats row.
- Card nhắc KYC nếu chưa.
- Không dùng ảnh 3D mascot của Green SM.

## 35. PromoStrip

- Nền promo pastel; icon 3D/line; tiêu đề 13; CTA text.
- 1 dòng, không che CTA chính.
- Không auto-play.
- Có dismiss nếu là quảng cáo.

## 36. StickySearch

- Search pill 52; nền trắng đặc khi top; glass khi cuộn >8px.
- Shadow tăng nhẹ; 180ms.
- Tap mở search full-screen.
- Không đặt 2 search trên màn.

## 37. Component rules

- Touch ≥44.
- Label ngoài input.
- Không icon-only nếu không có accessibility label.
- Loading không đổi layout.
- Error có text + icon.
- Không lồng bottom sheet trong bottom sheet.
- Modal confirm cho hành động phá huỷ.
