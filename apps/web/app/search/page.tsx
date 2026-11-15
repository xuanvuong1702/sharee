"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Suspense, useEffect, useMemo, useState } from "react";
import type { SearchResult } from "@sharee/api-client";
import { Badge, Button, Card, EmptyState } from "@sharee/ui";
import { useAuth } from "@/components/AuthProvider";
import { dateLabel, money, routePresets, timeLabel } from "@/lib/sharee";

function SearchResults() {
  const params = useSearchParams();
  const { api } = useAuth();
  const [items, setItems] = useState<SearchResult[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const query = useMemo(() => {
    const route = routePresets.find((item) => item.id === params.get("route")) ?? routePresets[0];
    return {
      fromLat: Number(params.get("fromLat") ?? route.fromLat),
      fromLng: Number(params.get("fromLng") ?? route.fromLng),
      toLat: Number(params.get("toLat") ?? route.toLat),
      toLng: Number(params.get("toLng") ?? route.toLng),
      date: params.get("date") ?? "",
      seats: Number(params.get("seats") ?? 1),
      fromLabel: params.get("fromLabel") ?? route.fromLabel,
      toLabel: params.get("toLabel") ?? route.toLabel,
    };
  }, [params]);

  useEffect(() => {
    setLoading(true);
    setError(null);
    api
      .search(query)
      .then((result) => setItems(result.items))
      .catch((err) => setError(err instanceof Error ? err.message : "Không tải được chuyến"))
      .finally(() => setLoading(false));
  }, [api, query]);

  return (
    <div className="sh-container page-section">
      <div className="page-heading">
        <div>
          <Link href="/" className="back-link">
            ← Trang chủ
          </Link>
          <h1>
            {query.fromLabel.split(",")[0]} → {query.toLabel.split(",")[0]}
          </h1>
          <p>
            {query.date ? dateLabel(query.date) : "Hôm nay"} · {query.seats} ghế ·{" "}
            {items.length} chuyến phù hợp
          </p>
        </div>
        <Link href="/#tim-chuyen" className="sh-btn sh-btn-ghost sh-btn-md">
          Đổi tìm kiếm
        </Link>
      </div>

      {loading ? (
        <div className="results-list">
          {[1, 2, 3].map((key) => (
            <div key={key} className="shimmer card-skeleton" />
          ))}
        </div>
      ) : error ? (
        <Card>
          <EmptyState title="Không tải được chuyến" message={error} />
        </Card>
      ) : items.length === 0 ? (
        <Card>
          <EmptyState
            title="Chưa có chuyến phù hợp"
            message="Thử đổi ngày hoặc tuyến đường khác. Bạn cũng có thể tải app để nhận thông báo khi có chuyến mới."
          />
        </Card>
      ) : (
        <div className="results-layout">
          <div className="results-list">
            {items.map((item) => (
              <Card key={item.tripId} className="trip-result">
                <div className="trip-result-main">
                  <div className="trip-time">
                    <strong>{timeLabel(item.departureTime)}</strong>
                    <span>{dateLabel(item.departureTime.slice(0, 10))}</span>
                  </div>
                  <div className="trip-route">
                    <span className="route-dot start" />
                    <div>
                      <strong>{item.pickupStop.name}</strong>
                      <small>{item.originLabel}</small>
                    </div>
                    <span className="route-line" />
                    <span className="route-dot end" />
                    <div>
                      <strong>{item.dropoffStop.name}</strong>
                      <small>{item.destinationLabel}</small>
                    </div>
                  </div>
                  <div className="trip-price">
                    <strong>{money(item.pricePerSeat)}</strong>
                    <span>/ ghế</span>
                  </div>
                </div>
                <div className="trip-result-foot">
                  <div className="driver-line">
                    <span className="avatar small">
                      {item.driver.fullName.slice(0, 1).toUpperCase()}
                    </span>
                    <span>{item.driver.fullName}</span>
                    <span className="rating">★ {item.driver.ratingAvg.toFixed(1)}</span>
                    <span className="muted">· {item.vehicle.make} {item.vehicle.model}</span>
                  </div>
                  <div className="trip-tags">
                    <Badge tone="green">Còn {item.seatsAvailable} ghế</Badge>
                    {item.bookingMode === "instant" ? (
                      <Badge tone="blue">Đặt ngay</Badge>
                    ) : (
                      <Badge tone="amber">Tài xế duyệt</Badge>
                    )}
                  </div>
                  <Link href={`/trip/?id=${item.tripId}&from=${item.pickupStop.id}&to=${item.dropoffStop.id}&seats=${query.seats}`}>
                    <Button>Chọn chuyến</Button>
                  </Link>
                </div>
              </Card>
            ))}
          </div>
          <aside className="results-aside">
            <Card>
              <h3>Mẹo đặt chuyến</h3>
              <ul>
                <li>Đặt trước 1–2 ngày để có nhiều lựa chọn.</li>
                <li>Kiểm tra điểm đón và giờ khởi hành.</li>
                <li>Nhắn tin với tài xế sau khi đặt.</li>
              </ul>
            </Card>
            <Card className="app-card">
              <strong>Tải app Sharee</strong>
              <p>Theo dõi chuyến, chat và tip tài xế thuận tiện hơn.</p>
              <a
                className="sh-btn sh-btn-primary sh-btn-md"
                href="https://github.com/xuanvuong1702/sharee/releases/latest"
                target="_blank"
                rel="noreferrer"
              >
                Tải APK
              </a>
            </Card>
          </aside>
        </div>
      )}
    </div>
  );
}

export default function SearchPage() {
  return (
    <Suspense fallback={<div className="sh-container page-section">Đang tải...</div>}>
      <SearchResults />
    </Suspense>
  );
}
