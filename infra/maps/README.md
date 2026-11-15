# Bản đồ production

Mobile dùng `flutter_map` với tile URL cấu hình qua `--dart-define`.

## Lựa chọn 1 — nhà cung cấp có SLA (khuyến nghị)

- Mapbox: `https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=KEY`
- MapTiler: `https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=KEY`
- Goong (Việt Nam): tile URL theo tài khoản Goong.

Build:

```bash
flutter build apk --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=MAP_TILE_URL="https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=KEY" \
  --dart-define=MAP_ATTRIBUTION="© MapTiler © OpenStreetMap contributors" \
  --dart-define=MAP_USER_AGENT="vn.sharee.mobile"
```

## Lựa chọn 2 — self-host (không cần API key)

Yêu cầu: Docker, ~5–8 GB dung lượng, RAM ≥ 4 GB.

```powershell
# PowerShell, từ thư mục repo
./infra/scripts/setup-map.ps1
```

Script tải `vietnam-latest.osm.pbf` từ Geofabrik, import vào tile server (lần đầu 10–20 phút),
sau đó chạy tile server tại `http://localhost:8082`.

Build mobile:

```bash
flutter build apk --dart-define=API_BASE_URL=http://10.0.2.2:8080 \
  --dart-define=MAP_TILE_URL="http://10.0.2.2:8082/tile/{z}/{x}/{y}.png" \
  --dart-define=MAP_ATTRIBUTION="© OpenStreetMap contributors" \
  --dart-define=MAP_USER_AGENT="vn.sharee.mobile"
```

Đổi `10.0.2.2` thành host/IP phù hợp khi chạy thiết bị thật và dùng HTTPS ở production.

## Lưu ý

- Không dùng tile OSM công cộng cho lưu lượng thương mại.
- Giữ attribution theo yêu cầu giấy phép.
- Tile server self-host là raster; nếu cần vector/3D, dùng MapLibre + tile vector có SLA.
