"use client";

import dynamic from "next/dynamic";
import type { LocationKind, MapPlace } from "./MapPickerInner";

const Inner = dynamic(() => import("./MapPickerInner"), {
  ssr: false,
  loading: () => <div className="map-picker-loading">Đang tải bản đồ...</div>,
});

export type { LocationKind, MapPlace };

export function MapPicker(props: {
  pickup: MapPlace | null;
  dropoff: MapPlace | null;
  active: LocationKind;
  onActiveChange: (kind: LocationKind) => void;
  onChange: (kind: LocationKind, place: MapPlace) => void;
  showActions?: boolean;
  height?: number;
}) {
  return <Inner {...props} />;
}
