"use client";

import dynamic from "next/dynamic";
import type { MapPlace } from "./MapPickerInner";

const Inner = dynamic(() => import("./MapPickerInner"), {
  ssr: false,
  loading: () => <div className="map-picker-loading">Đang tải bản đồ...</div>,
});

export type { MapPlace };

export function MapPicker(props: {
  pickup: MapPlace | null;
  dropoff: MapPlace | null;
  onChange: (kind: "pickup" | "dropoff", place: MapPlace) => void;
}) {
  return <Inner {...props} />;
}
