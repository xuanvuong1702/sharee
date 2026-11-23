"use client";

import { Fragment } from "react";
import { MapContainer, Marker, Polyline, Popup, TileLayer } from "react-leaflet";
import L from "leaflet";
import type { SearchResult } from "@sharee/api-client";

const icon = L.divIcon({
  className: "",
  html: `<div style="width:26px;height:26px;border-radius:50%;background:#0f9f8f;border:3px solid #fff;box-shadow:0 3px 10px rgba(0,0,0,.35);display:grid;place-items:center;color:#fff;font-size:12px">●</div>`,
  iconSize: [26, 26],
  iconAnchor: [13, 13],
});

export default function ResultsMapInner({ items }: { items: SearchResult[] }) {
  const first = items[0];
  const center: [number, number] = first
    ? [first.pickupStop.lat, first.pickupStop.lng]
    : [21.0278, 105.8342];

  return (
    <MapContainer center={center} zoom={12} style={{ height: 420, width: "100%" }}
      scrollWheelZoom>
      <TileLayer
        attribution="&copy; OpenStreetMap"
        url="https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}"
      />
      {items.map((item, index) => (
        <Fragment key={item.tripId}>
          <Polyline
            positions={[
              [item.pickupStop.lat, item.pickupStop.lng],
              [item.dropoffStop.lat, item.dropoffStop.lng],
            ]}
            pathOptions={{ color: index === 0 ? "#0f9f8f" : "#8aa3b5", weight: 3, opacity: .75 }}
          />
          <Marker position={[item.pickupStop.lat, item.pickupStop.lng]} icon={icon}>
            <Popup>
              <strong>{item.pickupStop.name}</strong><br />
              → {item.dropoffStop.name}<br />
              {new Intl.NumberFormat("vi-VN").format(item.pricePerSeat)}đ / ghế
            </Popup>
          </Marker>
        </Fragment>
      ))}
    </MapContainer>
  );
}
