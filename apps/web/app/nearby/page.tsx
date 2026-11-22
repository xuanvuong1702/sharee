"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Button, Card } from "@sharee/ui";
import { MapPicker, type MapPlace } from "@/components/MapPicker";
import { API_URL, nextDate } from "@/lib/sharee";

export default function NearbyPage() {
  const router = useRouter();
  const [pickup, setPickup] = useState<MapPlace | null>(null);
  const [dropoff, setDropoff] = useState<MapPlace | null>(null);
  const [date, setDate] = useState(nextDate());
  const [seats, setSeats] = useState(1);
  const [locating, setLocating] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!navigator.geolocation) { setLocating(false); return; }
    navigator.geolocation.getCurrentPosition(async (pos) => {
      const { latitude: lat, longitude: lng } = pos.coords;
      try {
        const res = await fetch(`${API_URL}/api/geo/reverse?lat=${lat}&lng=${lng}`);
        const data = res.ok ? await res.json() : null;
        setPickup({
          label: data?.label || "Vị trí hiện tại",
          fullName: data?.fullName || data?.full_name || `${lat}, ${lng}`,
          lat, lng,
        });
      } catch {
        setPickup({ label: "Vị trí hiện tại", fullName: `${lat}, ${lng}`, lat, lng });
      } finally {
        setLocating(false);
      }
    }, () => setLocating(false), { enableHighAccuracy: true, timeout: 10000 });
  }, []);

  function change(kind: "pickup" | "dropoff", place: MapPlace) {
    if (kind === "pickup") setPickup(place);
    else setDropoff(place);
  }

  function submit() {
    if (!pickup || !dropoff) { setError("Chọn điểm đón và điểm đến trên bản đồ."); return; }
    const params = new URLSearchParams({
      fromLat: String(pickup.lat), fromLng: String(pickup.lng),
      toLat: String(dropoff.lat), toLng: String(dropoff.lng),
      fromLabel: pickup.label, toLabel: dropoff.label,
      date, seats: String(seats),
    });
    router.push(`/search/?${params.toString()}`);
  }

  return (
    <div className="sh-container page-section">
      <div className="page-heading">
        <div>
          <Link href="/" className="back-link">← Trang chủ</Link>
          <h1>Tìm chuyến gần bạn</h1>
          <p>Bản đồ tự lấy vị trí hiện tại. Chạm bản đồ để chọn điểm đón và điểm đến.</p>
        </div>
      </div>
      <Card className="search-card">
        <div className="search-card-head">
          <h2>{locating ? "Đang xác định vị trí..." : pickup?.label || "Chọn điểm đón"}</h2>
          <p>{pickup?.fullName || "Bạn có thể chạm bản đồ hoặc dùng vị trí hiện tại."}</p>
        </div>
        <MapPicker pickup={pickup} dropoff={dropoff} onChange={change} />
        <div className="search-row">
          <label className="sh-field"><span>Ngày đi</span>
            <input type="date" value={date} onChange={(e) => setDate(e.target.value)} />
          </label>
          <label className="sh-field"><span>Số ghế</span>
            <select value={seats} onChange={(e) => setSeats(Number(e.target.value))}>
              {[1, 2, 3, 4].map((n) => <option key={n} value={n}>{n} ghế</option>)}
            </select>
          </label>
        </div>
        <div className="nearby-summary">
          <span>Đón: <strong>{pickup?.label || "chưa chọn"}</strong></span>
          <span>Đến: <strong>{dropoff?.label || "chưa chọn"}</strong></span>
        </div>
        {error && <div className="error">{error}</div>}
        <Button type="button" size="lg" onClick={submit} disabled={!pickup || !dropoff}>
          Tìm chuyến quanh đây
        </Button>
      </Card>
    </div>
  );
}
