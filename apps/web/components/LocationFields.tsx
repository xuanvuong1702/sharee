"use client";

import { useEffect, useRef, useState } from "react";
import { MapPicker, type MapPlace } from "./MapPicker";
import { API_URL } from "@/lib/sharee";

export type TripPlace = MapPlace;
type Kind = "pickup" | "dropoff";

type Props = {
  pickup: TripPlace | null;
  dropoff: TripPlace | null;
  onChange: (kind: Kind, place: TripPlace | null) => void;
  autoLocate?: boolean;
  compact?: boolean;
  inlineMap?: boolean;
  initialActive?: Kind;
};

const RECENT_KEY = "sharee.web.recentPlaces";
const distanceKm = (a: TripPlace, b: TripPlace) => {
  const r = 6371;
  const dLat = (b.lat - a.lat) * Math.PI / 180;
  const dLng = (b.lng - a.lng) * Math.PI / 180;
  const h = Math.sin(dLat / 2) ** 2 +
    Math.cos(a.lat * Math.PI / 180) * Math.cos(b.lat * Math.PI / 180) * Math.sin(dLng / 2) ** 2;
  return 2 * r * Math.asin(Math.sqrt(h));
};

export function LocationFields({
  pickup, dropoff, onChange, autoLocate = true, compact = false, inlineMap = false,
  initialActive,
}: Props) {
  const [active, setActive] = useState<Kind>(initialActive ?? (pickup ? "dropoff" : "pickup"));
  const [mapOpen, setMapOpen] = useState(false);
  const [pickupQuery, setPickupQuery] = useState(pickup?.label ?? "");
  const [dropoffQuery, setDropoffQuery] = useState(dropoff?.label ?? "");
  const [suggestions, setSuggestions] = useState<TripPlace[]>([]);
  const [recent, setRecent] = useState<TripPlace[]>([]);
  const [locating, setLocating] = useState(false);
  const [note, setNote] = useState("");
  const dropoffRef = useRef<HTMLInputElement>(null);

  function fallbackPickup(reason: string) {
    let place: TripPlace = {
      label: "Hà Nội (mặc định)",
      fullName: "Chạm bản đồ để chọn đúng vị trí của bạn",
      lat: 21.0278, lng: 105.8342,
    };
    try {
      const raw = localStorage.getItem(RECENT_KEY);
      const saved = raw ? JSON.parse(raw) as TripPlace[] : [];
      if (saved.length > 0) place = saved[0];
    } catch { /* ignore */ }
    onChange("pickup", place);
    setPickupQuery(place.label);
    setActive("dropoff");
    setNote(reason);
  }

  useEffect(() => {
    try {
      const raw = localStorage.getItem(RECENT_KEY);
      if (raw) setRecent(JSON.parse(raw) as TripPlace[]);
    } catch { /* ignore */ }
  }, []);

  useEffect(() => {
    if (!autoLocate || pickup) return;
    if (typeof window === "undefined" || !window.isSecureContext) {
      // HTTP deployment: browser geolocation is blocked. Use city-level IP
      // fallback so "near you" still starts somewhere useful, clearly labelled.
      fetch(`${API_URL}/api/geo/ip`).then(async (res) => {
        if (!res.ok) throw new Error("no ip location");
        const data = await res.json();
        const place: TripPlace = {
          label: `${data.label || "Khu vực của bạn"} (ước tính)`,
          fullName: data.fullName || data.label || "Vị trí ước tính theo IP",
          lat: data.lat, lng: data.lng,
        };
        onChange("pickup", place);
        setPickupQuery(place.label);
        setActive("dropoff");
        setNote("GPS cần HTTPS, nên điểm đón đang được ước tính theo IP. Chạm bản đồ nếu chưa đúng.");
      }).catch(() => fallbackPickup(
        "GPS chỉ hoạt động trên HTTPS. Đang dùng Hà Nội/địa điểm gần đây; chạm bản đồ để đổi."));
      return;
    }
    if (!navigator.geolocation) {
      fallbackPickup("Trình duyệt không hỗ trợ định vị. Đang dùng Hà Nội/địa điểm gần đây.");
      return;
    }
    setLocating(true);
    navigator.geolocation.getCurrentPosition(async (pos) => {
      const { latitude: lat, longitude: lng } = pos.coords;
      let place: TripPlace = {
        label: "Vị trí hiện tại",
        fullName: `${lat.toFixed(5)}, ${lng.toFixed(5)}`,
        lat, lng,
      };
      try {
        const res = await fetch(`${API_URL}/api/geo/reverse?lat=${lat}&lng=${lng}`);
        if (res.ok) {
          const data = await res.json();
          place = {
            label: data.label || place.label,
            fullName: data.fullName || data.full_name || place.fullName,
            lat, lng,
          };
        }
      } catch { /* fallback coordinates */ }
      onChange("pickup", place);
      setPickupQuery(place.label);
      setActive("dropoff");
      setLocating(false);
      setTimeout(() => dropoffRef.current?.focus(), 150);
    }, () => {
      setLocating(false);
      fallbackPickup("Không lấy được GPS. Đang dùng Hà Nội/địa điểm gần đây; chạm bản đồ để đổi.");
    }, { enableHighAccuracy: true, timeout: 10000 });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [autoLocate]);

  useEffect(() => {
    if (pickup) setPickupQuery(pickup.label);
  }, [pickup]);
  useEffect(() => {
    if (dropoff) setDropoffQuery(dropoff.label);
  }, [dropoff]);

  useEffect(() => {
    const query = (active === "pickup" ? pickupQuery : dropoffQuery).trim();
    if (query.length < 2) { setSuggestions([]); return; }
    const timer = setTimeout(async () => {
      try {
        const res = await fetch(`${API_URL}/api/geo/search?q=${encodeURIComponent(query)}&limit=6`);
        if (!res.ok) { setSuggestions([]); return; }
        const data = await res.json();
        setSuggestions(Array.isArray(data) ? data : data.items ?? []);
      } catch { setSuggestions([]); }
    }, 280);
    return () => clearTimeout(timer);
  }, [active, pickupQuery, dropoffQuery]);

  function remember(place: TripPlace) {
    const next = [place, ...recent.filter((p) =>
      p.lat !== place.lat || p.lng !== place.lng)].slice(0, 5);
    setRecent(next);
    try { localStorage.setItem(RECENT_KEY, JSON.stringify(next)); } catch { /* ignore */ }
  }

  function choose(kind: Kind, place: TripPlace) {
    onChange(kind, place);
    if (kind === "pickup") {
      setPickupQuery(place.label);
      setActive("dropoff");
      setTimeout(() => dropoffRef.current?.focus(), 100);
    } else {
      setDropoffQuery(place.label);
    }
    remember(place);
    setSuggestions([]);
    setNote("");
    if (kind === "dropoff" && mapOpen) setMapOpen(false);
  }

  function edit(kind: Kind, value: string) {
    setActive(kind);
    onChange(kind, null);
    if (kind === "pickup") setPickupQuery(value);
    else setDropoffQuery(value);
  }

  function useCurrent() {
    if (typeof window === "undefined" || !window.isSecureContext) {
      fetch(`${API_URL}/api/geo/ip`).then(async (res) => {
        if (!res.ok) throw new Error("no ip location");
        const data = await res.json();
        const place: TripPlace = {
          label: `${data.label || "Khu vực của bạn"} (ước tính)`,
          fullName: data.fullName || "Vị trí ước tính theo IP",
          lat: data.lat, lng: data.lng,
        };
        choose("pickup", place);
        setNote("Đang dùng vị trí ước tính theo IP. Chạm bản đồ nếu chưa đúng.");
      }).catch(() => setNote("GPS chỉ hoạt động trên HTTPS. Bạn có thể chọn điểm đón trên bản đồ."));
      return;
    }
    if (!navigator.geolocation) { setNote("Trình duyệt không hỗ trợ định vị."); return; }
    setLocating(true);
    navigator.geolocation.getCurrentPosition(async (pos) => {
      const { latitude: lat, longitude: lng } = pos.coords;
      let place: TripPlace = { label: "Vị trí hiện tại", fullName: `${lat}, ${lng}`, lat, lng };
      try {
        const res = await fetch(`${API_URL}/api/geo/reverse?lat=${lat}&lng=${lng}`);
        if (res.ok) {
          const data = await res.json();
          place = { label: data.label || place.label,
            fullName: data.fullName || data.full_name || place.fullName, lat, lng };
        }
      } catch { /* fallback */ }
      choose("pickup", place);
      setLocating(false);
    }, () => {
      setLocating(false);
      setNote("Bạn chưa cấp quyền vị trí. Hãy tìm địa chỉ hoặc chạm bản đồ.");
    }, { enableHighAccuracy: true, timeout: 10000 });
  }

  const route = pickup && dropoff ? distanceKm(pickup, dropoff) : null;
  const routeLabel = route == null ? null
    : route < 1 ? `${Math.round(route * 1000)} m`
      : `${route.toFixed(1)} km · khoảng ${Math.max(5, Math.round(route / 25 * 60))} phút`;

  return (
    <div className={`location-fields ${compact ? "compact" : ""}`}>
      <div className="location-field-row">
        <span className="location-dot pickup" />
        <label className="location-input-wrap">
          <span>Điểm đón</span>
          <input
            value={pickupQuery}
            onFocus={() => setActive("pickup")}
            onChange={(e) => edit("pickup", e.target.value)}
            placeholder={locating ? "Đang lấy vị trí..." : "Chọn điểm đón hoặc dùng vị trí hiện tại"}
            autoComplete="off"
          />
        </label>
        <button type="button" className="location-swap" title="Đổi chiều"
          onClick={() => {
            const p = pickup; const d = dropoff;
            onChange("pickup", d);
            onChange("dropoff", p);
            setPickupQuery(d?.label ?? "");
            setDropoffQuery(p?.label ?? "");
          }}>⇅</button>
      </div>
      <div className="location-field-row">
        <span className="location-dot dropoff" />
        <label className="location-input-wrap">
          <span>Điểm đến</span>
          <input
            ref={dropoffRef}
            value={dropoffQuery}
            onFocus={() => setActive("dropoff")}
            onChange={(e) => edit("dropoff", e.target.value)}
            placeholder="Bạn muốn đi đâu?"
            autoComplete="off"
          />
        </label>
      </div>
      {suggestions.length > 0 && (
        <div className="search-suggestions location-suggestions">
          {suggestions.slice(0, 6).map((place) => (
            <button type="button" key={`${place.lat}-${place.lng}`}
              onClick={() => choose(active, place)}>
              <strong>{place.label}</strong>
              <small>{place.fullName}</small>
            </button>
          ))}
        </div>
      )}
      <div className="location-actions">
        <button type="button" onClick={useCurrent}>⌖ Vị trí của tôi</button>
        <button type="button" onClick={() => setMapOpen(true)}>▦ Chọn trên bản đồ</button>
        {recent.length > 0 && recent.slice(0, 3).map((place) => (
          <button type="button" key={`${place.lat}-${place.lng}`}
            className="recent-chip" onClick={() => choose(active, place)}>
            {place.label}
          </button>
        ))}
      </div>
      {note && <p className="location-note">{note}</p>}
      {inlineMap && (
        <MapPicker
          pickup={pickup}
          dropoff={dropoff}
          active={active}
          onActiveChange={setActive}
          onChange={(kind, place) => choose(kind, place)}
          showActions={false}
          height={compact ? 210 : 280}
        />
      )}
      {mapOpen && (
        <div className="map-modal" role="dialog" aria-modal="true"
          onClick={(e) => { if (e.target === e.currentTarget) setMapOpen(false); }}>
          <div className="map-modal-card">
            <div className="map-modal-head">
              <strong>Chọn {active === "pickup" ? "điểm đón" : "điểm đến"} trên bản đồ</strong>
              <button type="button" onClick={() => setMapOpen(false)} aria-label="Đóng">×</button>
            </div>
            <MapPicker
              pickup={pickup}
              dropoff={dropoff}
              active={active}
              onActiveChange={setActive}
              onChange={(kind, place) => choose(kind, place)}
              showActions
              height={420}
            />
            <div className="map-modal-foot">
              <button type="button" className="sh-btn sh-btn-primary sh-btn-md"
                onClick={() => setMapOpen(false)}>Xong</button>
            </div>
          </div>
        </div>
      )}
      {routeLabel && <p className="location-route">Tuyến ước tính: {routeLabel}</p>}
    </div>
  );
}
