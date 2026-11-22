"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Button, Card, Field } from "@sharee/ui";
import { useAuth } from "@/components/AuthProvider";
import { MapPicker } from "@/components/MapPicker";
import { API_URL } from "@/lib/sharee";

type Place = { label: string; fullName: string; lat: number; lng: number };
type Vehicle = { id: string; make: string; model: string; plate: string; seats: number };

export default function PublishPage() {
  const { token, user, ready } = useAuth();
  const router = useRouter();
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [vehicleId, setVehicleId] = useState("");
  const [from, setFrom] = useState<Place | null>(null);
  const [to, setTo] = useState<Place | null>(null);
  const [fromQuery, setFromQuery] = useState("");
  const [toQuery, setToQuery] = useState("");
  const [suggestions, setSuggestions] = useState<Place[]>([]);
  const [active, setActive] = useState<"from" | "to" | null>(null);
  const [departure, setDeparture] = useState(() => {
    const d = new Date(Date.now() + 86400000);
    d.setHours(8, 0, 0, 0);
    return d.toISOString().slice(0, 16);
  });
  const [price, setPrice] = useState(180000);
  const [seats, setSeats] = useState(3);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!token) return;
    fetch(`${API_URL}/api/vehicles`, { headers: { Authorization: `Bearer ${token}` } })
      .then((res) => (res.ok ? res.json() : []))
      .then((data) => {
        setVehicles(Array.isArray(data) ? data : data.items ?? []);
        if (data?.[0]?.id) setVehicleId(data[0].id);
      })
      .catch(() => setVehicles([]));
  }, [token]);

  useEffect(() => {
    const query = (active === "from" ? fromQuery : toQuery).trim();
    if (!active || query.length < 2) { setSuggestions([]); return; }
    const timer = setTimeout(async () => {
      const res = await fetch(`${API_URL}/api/geo/search?q=${encodeURIComponent(query)}`);
      if (res.ok) {
        const data = await res.json();
        setSuggestions(Array.isArray(data) ? data : data.items ?? []);
      }
    }, 300);
    return () => clearTimeout(timer);
  }, [active, fromQuery, toQuery]);

  const choose = (place: Place) => {
    if (active === "from") { setFrom(place); setFromQuery(place.label); }
    else { setTo(place); setToQuery(place.label); }
    setSuggestions([]); setActive(null);
  };

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    if (!token) { router.push("/login/"); return; }
    if (!from || !to || !vehicleId) { setError("Chọn điểm đón, điểm đến và xe."); return; }
    setBusy(true); setError("");
    try {
      const body = {
        vehicleId,
        origin: { lat: from.lat, lng: from.lng, label: from.label },
        destination: { lat: to.lat, lng: to.lng, label: to.label },
        departureTime: new Date(departure).toISOString(),
        pricePerSeat: price,
        seatsTotal: seats,
        bookingMode: "instant",
        luggage: true,
        petsAllowed: false,
        smokingAllowed: false,
        stops: [
          { name: from.label, lat: from.lat, lng: from.lng, allowPickup: true, allowDropoff: false },
          { name: to.label, lat: to.lat, lng: to.lng, allowPickup: false, allowDropoff: true },
        ],
      };
      const res = await fetch(`${API_URL}/api/trips`, {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
        body: JSON.stringify(body),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data.error || "Không đăng được chuyến");
      router.push(`/trip/?id=${data.id}`);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Không đăng được chuyến");
    } finally {
      setBusy(false);
    }
  }

  if (ready && !user) {
    return <div className="sh-container page-section"><Card><p>Vui lòng đăng nhập để đăng chuyến.</p></Card></div>;
  }

  return (
    <div className="sh-container page-section">
      <div className="page-heading">
        <div>
          <h1>Đăng chuyến</h1>
          <p>Chia sẻ ghế trống và chọn tuyến theo địa chỉ thực tế.</p>
        </div>
      </div>
      <Card className="search-card">
        <form onSubmit={submit} className="search-form">
          <label className="sh-field"><span>Điểm đón</span>
            <input value={fromQuery} placeholder="Số nhà, đường..."
              onFocus={() => setActive("from")}
              onChange={(e) => { setFromQuery(e.target.value); setFrom(null); setActive("from"); }} />
          </label>
          <label className="sh-field"><span>Điểm đến</span>
            <input value={toQuery} placeholder="Số nhà, đường..."
              onFocus={() => setActive("to")}
              onChange={(e) => { setToQuery(e.target.value); setTo(null); setActive("to"); }} />
          </label>
          {active && suggestions.length > 0 && (
            <div className="search-suggestions">
              {suggestions.slice(0, 6).map((place) => (
                <button type="button" key={`${place.lat}-${place.lng}`} onClick={() => choose(place)}>
                  <strong>{place.label}</strong><small>{place.fullName}</small>
                </button>
              ))}
            </div>
          )}
          <MapPicker pickup={from} dropoff={to}
            onChange={(kind, place) => {
              if (kind === "pickup") { setFrom(place); setFromQuery(place.label); }
              else { setTo(place); setToQuery(place.label); }
            }} />
          <label className="sh-field"><span>Xe</span>
            <select value={vehicleId} onChange={(e) => setVehicleId(e.target.value)}>
              {vehicles.map((v) => <option key={v.id} value={v.id}>{v.make} {v.model} · {v.plate}</option>)}
            </select>
          </label>
          <div className="search-row">
            <Field label="Khởi hành" type="datetime-local" value={departure}
              onChange={(e) => setDeparture(e.target.value)} />
            <Field label="Giá / ghế" type="number" value={price}
              onChange={(e) => setPrice(Number(e.target.value))} />
            <label className="sh-field"><span>Số ghế</span>
              <select value={seats} onChange={(e) => setSeats(Number(e.target.value))}>
                {[1, 2, 3, 4, 5, 6, 7, 8].map((n) => <option key={n} value={n}>{n}</option>)}
              </select>
            </label>
          </div>
          {vehicles.length === 0 && <div className="hint">Bạn cần thêm xe trong app mobile trước khi đăng chuyến.</div>}
          {error && <div className="error">{error}</div>}
          <Button type="submit" size="lg" disabled={busy || !from || !to || !vehicleId}>
            {busy ? "Đang đăng..." : "Đăng chuyến"}
          </Button>
        </form>
      </Card>
    </div>
  );
}
