"use client";

import dynamic from "next/dynamic";
import type { SearchResult } from "@sharee/api-client";

const Inner = dynamic(() => import("./ResultsMapInner"), {
  ssr: false,
  loading: () => <div className="results-map-loading">Đang tải bản đồ...</div>,
});

export function ResultsMap({ items }: { items: SearchResult[] }) {
  if (items.length === 0) return null;
  return <Inner items={items} />;
}
