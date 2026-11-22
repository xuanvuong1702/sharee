"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Button, Card } from "@sharee/ui";
import { LocationFields, type TripPlace } from "@/components/LocationFields";
import { nextDate } from "@/lib/sharee";

export default function NearbyPage() {
  const router = useRouter();
  const [pickup, setPickup] = useState<TripPlace | null>(null);
  const [dropoff, setDropoff] = useState<TripPlace | null>(null);
  const [date, setDate] = useState(nextDate());
  const [seats, setSeats] = useState(1);
  const [error, setError] = useState("");

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
          <p>Điểm đón tự lấy GPS. Chạm bản đồ hoặc gõ địa chỉ để chọn điểm đến.</p>
        </div>
      </div>
      <Card className="search-card">
        <LocationFields
          pickup={pickup}
          dropoff={dropoff}
          onChange={(kind, place) => kind === "pickup" ? setPickup(place) : setDropoff(place)}
          inlineMap
        />
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
        {error && <div className="error">{error}</div>}
        <Button type="button" size="lg" onClick={submit} disabled={!pickup || !dropoff}>
          Tìm chuyến quanh đây
        </Button>
      </Card>
    </div>
  );
}
