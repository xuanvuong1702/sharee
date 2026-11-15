"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button, Card, Field } from "@sharee/ui";
import { nextDate, routePresets } from "@/lib/sharee";

export function SearchBox({ compact = false }: { compact?: boolean }) {
  const router = useRouter();
  const [routeId, setRouteId] = useState(routePresets[0].id);
  const [date, setDate] = useState(nextDate());
  const [seats, setSeats] = useState(1);

  const submit = (event: React.FormEvent) => {
    event.preventDefault();
    const route = routePresets.find((item) => item.id === routeId) ?? routePresets[0];
    const params = new URLSearchParams({
      route: route.id,
      fromLat: String(route.fromLat),
      fromLng: String(route.fromLng),
      toLat: String(route.toLat),
      toLng: String(route.toLng),
      fromLabel: route.fromLabel,
      toLabel: route.toLabel,
      date,
      seats: String(seats),
    });
    router.push(`/search/?${params.toString()}`);
  };

  return (
    <Card className={compact ? "search-card search-card-compact" : "search-card"}>
      <div className="search-card-head">
        <h2>Tìm chuyến</h2>
        <p>Chọn tuyến, ngày và số ghế</p>
      </div>
      <form onSubmit={submit} className="search-form">
        <label className="sh-field">
          <span>Tuyến đường</span>
          <select value={routeId} onChange={(event) => setRouteId(event.target.value)}>
            {routePresets.map((route) => (
              <option key={route.id} value={route.id}>
                {route.name}
              </option>
            ))}
          </select>
        </label>
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
                <option key={value} value={value}>
                  {value} ghế
                </option>
              ))}
            </select>
          </label>
        </div>
        <Button type="submit" size="lg">
          Tìm chuyến
        </Button>
      </form>
      <div className="search-note">
        <span className="dot" /> Thanh toán an toàn · Hỗ trợ hoàn tiền
      </div>
    </Card>
  );
}
