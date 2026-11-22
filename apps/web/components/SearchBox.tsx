"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button, Card, Field } from "@sharee/ui";
import { LocationFields, type TripPlace } from "@/components/LocationFields";
import { nextDate } from "@/lib/sharee";

export function SearchBox({ compact = false }: { compact?: boolean }) {
  const router = useRouter();
  const [from, setFrom] = useState<TripPlace | null>(null);
  const [to, setTo] = useState<TripPlace | null>(null);
  const [date, setDate] = useState(nextDate());
  const [seats, setSeats] = useState(1);

  const submit = (event: React.FormEvent) => {
    event.preventDefault();
    if (!from || !to) return;
    const params = new URLSearchParams({
      fromLat: String(from.lat),
      fromLng: String(from.lng),
      toLat: String(to.lat),
      toLng: String(to.lng),
      fromLabel: from.label,
      toLabel: to.label,
      date,
      seats: String(seats),
    });
    router.push(`/search/?${params.toString()}`);
  };

  return (
    <Card className={compact ? "search-card search-card-compact" : "search-card"}>
      <div className="search-card-head">
        <h2>Tìm chuyến</h2>
        <p>Dùng vị trí hiện tại hoặc chọn điểm đón trên bản đồ, sau đó chọn điểm đến.</p>
      </div>
      <form onSubmit={submit} className="search-form">
        <LocationFields
          pickup={from}
          dropoff={to}
          onChange={(kind, place) => kind === "pickup" ? setFrom(place) : setTo(place)}
          compact={compact}
        />
        <div className="search-row">
          <Field
            label="Ngày đi"
            type="date"
            value={date}
            onChange={(event) => setDate(event.target.value)}
          />
          <label className="sh-field">
            <span>Số ghế</span>
            <select value={seats} onChange={(event) => setSeats(Number(event.target.value))}>
              {[1, 2, 3, 4].map((value) => (
                <option key={value} value={value}>{value} ghế</option>
              ))}
            </select>
          </label>
        </div>
        <Button type="submit" size="lg" disabled={!from || !to}>Tìm chuyến</Button>
      </form>
      <div className="search-note">
        <span className="dot" /> Thanh toán an toàn · Hỗ trợ hoàn tiền
      </div>
    </Card>
  );
}
