"use client";

import { useEffect, useState } from "react";
import { MapContainer, Marker, Polyline, TileLayer, useMap, useMapEvents } from "react-leaflet";
import L from "leaflet";
import { API_URL } from "@/lib/sharee";

export type MapPlace = { label: string; fullName: string; lat: number; lng: number };
export type LocationKind = "pickup" | "dropoff";

type Props = {
  pickup: MapPlace | null;
  dropoff: MapPlace | null;
  active: LocationKind;
  onActiveChange: (kind: LocationKind) => void;
  onChange: (kind: LocationKind, place: MapPlace) => void;
  showActions?: boolean;
  height?: number;
};

const icon = (color: string) => L.divIcon({
  className: "",
  html: `<div style="width:22px;height:22px;border-radius:50%;background:${color};border:3px solid #fff;box-shadow:0 2px 8px rgba(0,0,0,.3)"></div>`,
  iconSize: [22, 22],
  iconAnchor: [11, 11],
});

function ClickHandler({ onPick }: { onPick: (lat: number, lng: number) => void }) {
  useMapEvents({ click(e) { onPick(e.latlng.lat, e.latlng.lng); } });
  return null;
}

function Recenter({ lat, lng }: { lat?: number; lng?: number }) {
  const map = useMap();
  useEffect(() => {
    if (lat != null && lng != null) map.setView([lat, lng], 14);
  }, [lat, lng, map]);
  return null;
}

export default function MapPickerInner({
  pickup, dropoff, active, onActiveChange, onChange, showActions = true, height = 320,
}: Props) {
  const [busy, setBusy] = useState(false);
  const center: [number, number] = pickup
    ? [pickup.lat, pickup.lng]
    : dropoff
      ? [dropoff.lat, dropoff.lng]
      : [21.0278, 105.8342];

  async function pick(lat: number, lng: number) {
    setBusy(true);
    const kind = active;
    try {
      let place: MapPlace = {
        label: "Vị trí đã chọn",
        fullName: `${lat.toFixed(5)}, ${lng.toFixed(5)}`,
        lat, lng,
      };
      try {
        const res = await fetch(`${API_URL}/api/geo/reverse?lat=${lat}&lng=${lng}`);
        if (res.ok) {
          const data = await res.json();
          place = {
            label: data.label || data.name || place.label,
            fullName: data.fullName || data.full_name || place.fullName,
            lat, lng,
          };
        }
      } catch {
        // Keep coordinate label when reverse geocoding is unavailable.
      }
      onChange(kind, place);
      if (kind === "pickup") onActiveChange("dropoff");
    } finally {
      setBusy(false);
    }
  }

  function locate() {
    if (!navigator.geolocation) return;
    navigator.geolocation.getCurrentPosition(
      (pos) => pick(pos.coords.latitude, pos.coords.longitude),
      () => undefined,
      { enableHighAccuracy: true, timeout: 8000 },
    );
  }

  return (
    <div className="map-picker">
      {showActions && (
        <div className="map-picker-actions">
          <button type="button" className={active === "pickup" ? "active" : ""}
            onClick={() => onActiveChange("pickup")}>Điểm đón</button>
          <button type="button" className={active === "dropoff" ? "active" : ""}
            onClick={() => onActiveChange("dropoff")}>Điểm đến</button>
          <button type="button" onClick={locate}>Vị trí của tôi</button>
        </div>
      )}
      <MapContainer center={center} zoom={14} style={{ height, width: "100%" }}
        scrollWheelZoom>
        <TileLayer
          attribution="&copy; OpenStreetMap"
          url="https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}"
        />
        {pickup && dropoff && (
          <Polyline
            positions={[[pickup.lat, pickup.lng], [dropoff.lat, dropoff.lng]]}
            pathOptions={{ color: "#0f9f8f", weight: 4, opacity: 0.8 }}
          />
        )}
        {pickup && <Marker position={[pickup.lat, pickup.lng]} icon={icon("#0f9f8f")} />}
        {dropoff && <Marker position={[dropoff.lat, dropoff.lng]} icon={icon("#f59e0b")} />}
        <ClickHandler onPick={pick} />
        <Recenter lat={pickup?.lat ?? dropoff?.lat} lng={pickup?.lng ?? dropoff?.lng} />
      </MapContainer>
      <p className="map-picker-hint">
        {busy ? "Đang lấy địa chỉ..." : `Chạm bản đồ để chọn ${active === "pickup" ? "điểm đón" : "điểm đến"}`}
      </p>
    </div>
  );
}
