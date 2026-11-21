"use client";

import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { Button, Card, Field } from "@sharee/ui";
import { nextDate } from "@/lib/sharee";

const API = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8080";

type Place = { label: string; fullName: string; lat: number; lng: number };

export function SearchBox({ compact = false }: { compact?: boolean }) {
  const router = useRouter();
  const [from, setFrom] = useState<Place | null>(null);
  const [to, setTo] = useState<Place | null>(null);
  const [fromQuery, setFromQuery] = useState("");
  const [toQuery, setToQuery] = useState("");
  const [suggestions, setSuggestions] = useState<Place[]>([]);
  const [active, setActive] = useState<"from" | "to" | null>(null);
  const [date, setDate] = useState(nextDate());
  const [seats, setSeats] = useState(1);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    const query = (active === "from" ? fromQuery : toQuery).trim();
    if (!active || query.length < 2) {
      setSuggestions([]);
      return;
    }
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(async () => {
      try {
        const res = await fetch(`${API}/api/geo/search?q=${encodeURIComponent(query)}`);
        if (!res.ok) return;
        const data = await res.json();
        setSuggestions(Array.isArray(data) ? data : data.items ?? []);
      } catch {
        setSuggestions([]);
      }
    }, 300);
    return () => {
      if (timer.current) clearTimeout(timer.current);
    };
  }, [active, fromQuery, toQuery]);

  const choose = (place: Place) => {
    if (active === "from") {
      setFrom(place);
      setFromQuery(place.label);
    } else {
      setTo(place);
      setToQuery(place.label);
    }
    setSuggestions([]);
    setActive(null);
  };

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
        <p>Chọn điểm đón, điểm đến, ngày và số ghế</p>
      </div>
      <form onSubmit={submit} className="search-form">
        <label className="sh-field">
          <span>Điểm đón</span>
          <input
            value={fromQuery}
            onFocus={() => setActive("from")}
            onChange={(event) => {
              setFromQuery(event.target.value);
              setFrom(null);
              setActive("from");
            }}
            placeholder="Số nhà, đường, phường..."
            autoComplete="off"
          />
        </label>
        <label className="sh-field">
          <span>Điểm đến</span>
          <input
            value={toQuery}
            onFocus={() => setActive("to")}
            onChange={(event) => {
              setToQuery(event.target.value);
              setTo(null);
              setActive("to");
            }}
            placeholder="Số nhà, đường, phường..."
            autoComplete="off"
          />
        </label>
        {active && suggestions.length > 0 && (
          <div className="search-suggestions">
            {suggestions.slice(0, 6).map((place) => (
              <button type="button" key={`${place.lat}-${place.lng}`}
                onClick={() => choose(place)}>
                <strong>{place.label}</strong>
                <small>{place.fullName}</small>
              </button>
            ))}
          </div>
        )}
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
