"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Badge, Card } from "@sharee/ui";
import { API_URL } from "@/lib/sharee";

type Line = {
  id: string; name: string; brand?: string; description?: string;
  distanceM?: number | null; stopsCount?: number;
};

export default function DailyPage() {
  const [lines, setLines] = useState<Line[]>([]);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    fetch(`${API_URL}/api/daily/lines`)
      .then((res) => res.ok ? res.json() : [])
      .then((data) => setLines(Array.isArray(data) ? data : data.items ?? []))
      .catch(() => setLines([]))
      .finally(() => setLoading(false));
  }, []);

  return (
    <div className="sh-container page-section">
      <div className="page-heading">
        <div>
          <span className="sh-eyebrow">DAILY SHUTTLE</span>
          <h1>Đi làm mỗi ngày, giá cố định</h1>
          <p>Tuyến shuttle nội thành, đặt vé điện tử và lên xe tại trạm gần bạn.</p>
        </div>
        <Link href="/account/" className="sh-btn sh-btn-ghost sh-btn-md">Vé của tôi</Link>
      </div>

      {loading ? <div className="shimmer card-skeleton" /> : (
        <div className="air-listing-grid">
          {lines.length === 0 ? (
            <Card><p>Chưa có tuyến Daily đang mở.</p></Card>
          ) : lines.map((line) => (
            <Card key={line.id} className="daily-card">
              <div className="daily-icon">▤</div>
              <Badge tone="green">Daily</Badge>
              <h3>{line.name}</h3>
              <p>{line.description || line.brand || "Tuyến shuttle nội thành"}</p>
              <small>
                {line.stopsCount ?? 0} trạm
                {line.distanceM ? ` · cách bạn ${(line.distanceM / 1000).toFixed(1)} km` : ""}
              </small>
              <div className="daily-foot">
                <Link href="/account/">Đặt vé trên app →</Link>
              </div>
            </Card>
          ))}
        </div>
      )}
      <Card className="daily-note">
        <strong>Vé điện tử</strong>
        <p>Mua vé trên app để nhận mã QR và xác nhận với tài xế khi lên xe.</p>
      </Card>
    </div>
  );
}
