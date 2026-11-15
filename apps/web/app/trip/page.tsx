"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Suspense, useEffect, useMemo, useState } from "react";
import type { Booking, Trip } from "@sharee/api-client";
import { Badge, Button, Card, EmptyState } from "@sharee/ui";
import { useAuth } from "@/components/AuthProvider";
import { dateLabel, money, statusLabel, timeLabel } from "@/lib/sharee";

function TripView() {
  const params = useSearchParams();
  const id = params.get("id") ?? "";
  const { api, user } = useAuth();
  const [trip, setTrip] = useState<Trip | null>(null);
  const [booking, setBooking] = useState<Booking | null>(null);
  const [seats, setSeats] = useState(Number(params.get("seats") ?? 1));
  const [loading, setLoading] = useState(true);
  const [bookingBusy, setBookingBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!id) return;
    setLoading(true);
    api
      .trip(id)
      .then((data) => setTrip(data))
      .catch((err) => setError(err instanceof Error ? err.message : "Không tải được chuyến"))
      .finally(() => setLoading(false));
  }, [api, id]);

  const pickups = useMemo(
    () => (trip?.stops ?? []).filter((stop) => stop.allowPickup),
    [trip],
  );
  const dropoffs = useMemo(
    () => (trip?.stops ?? []).filter((stop) => stop.allowDropoff),
    [trip],
  );
  const initialFrom = params.get("from") ?? pickups[0]?.id ?? "";
  const initialTo = params.get("to") ?? dropoffs[dropoffs.length - 1]?.id ?? "";
  const [fromId, setFromId] = useState(initialFrom);
  const [toId, setToId] = useState(initialTo);

  useEffect(() => {
    if (!fromId && pickups[0]) setFromId(pickups[0].id);
    if (!toId && dropoffs[dropoffs.length - 1]) setToId(dropoffs[dropoffs.length - 1].id);
  }, [dropoffs, fromId, pickups, toId]);

  const from = pickups.find((stop) => stop.id === fromId);
  const to = dropoffs.find((stop) => stop.id === toId);
  const validRoute = from && to && from.seq < to.seq;
  const total = validRoute ? (to.priceFromOrigin - from.priceFromOrigin) * seats : 0;
  const next = `/trip/?id=${id}&from=${fromId}&to=${toId}&seats=${seats}`;

  const submit = async () => {
    if (!validRoute || !from || !to) return;
    if (!user) {
      window.location.href = `/login/?next=${encodeURIComponent(next)}`;
      return;
    }
    setBookingBusy(true);
    setError(null);
    try {
      let created = await api.createBooking(id, seats, from.id, to.id);
      if (created.status === "pending_payment") {
        try {
          created = await api.pay(created.id);
        } catch {
          // PayOS production flow is handled in the mobile app for now.
        }
      }
      setBooking(created);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Không đặt được chuyến");
    } finally {
      setBookingBusy(false);
    }
  };

  if (loading) {
    return (
      <div className="sh-container page-section">
        <div className="shimmer card-skeleton large" />
      </div>
    );
  }
  if (error && !trip) {
    return (
      <div className="sh-container page-section">
        <Card>
          <EmptyState title="Không tìm thấy chuyến" message={error} />
        </Card>
      </div>
    );
  }
  if (!trip) return null;

  return (
    <div className="sh-container page-section">
      <Link href="/" className="back-link">
        ← Tìm chuyến khác
      </Link>
      <div className="trip-detail-layout">
        <div>
          <Card className="trip-detail-head">
            <div className="trip-detail-top">
              <Badge tone="blue">{dateLabel(trip.departureTime)}</Badge>
              <Badge tone="green">Còn {trip.seatsAvailable} ghế</Badge>
            </div>
            <h1>
              {trip.origin.label.split(",")[0]} → {trip.destination.label.split(",")[0]}
            </h1>
            <p className="trip-detail-time">
              {timeLabel(trip.departureTime)} · {trip.vehicle.make} {trip.vehicle.model}
            </p>
            <div className="route-timeline">
              {trip.stops.map((stop) => (
                <div key={stop.id} className="timeline-stop">
                  <span className={`timeline-dot ${stop.allowPickup ? "pickup" : ""}`} />
                  <div>
                    <strong>{stop.name}</strong>
                    <small>
                      {stop.allowPickup ? "Có thể đón" : "Không đón"} ·{" "}
                      {stop.allowDropoff ? "Có thể trả" : "Không trả"}
                    </small>
                  </div>
                  <span>{money(stop.priceFromOrigin)}</span>
                </div>
              ))}
            </div>
            <div className="driver-card">
              <span className="avatar large">{trip.driver.fullName.slice(0, 1).toUpperCase()}</span>
              <div>
                <strong>{trip.driver.fullName}</strong>
                <p>
                  ★ {trip.driver.ratingAvg.toFixed(1)} · {trip.driver.ratingCount} đánh giá ·{" "}
                  {trip.vehicle.make} {trip.vehicle.model}
                </p>
                <small>Biển số {trip.vehicle.plate}</small>
              </div>
            </div>
          </Card>
        </div>

        <aside>
          <Card className="booking-box">
            {booking ? (
              <div className="booking-success">
                <div className="success-icon">✓</div>
                <h2>Đã đặt chuyến</h2>
                <p>
                  {booking.trip.originLabel.split(",")[0]} →{" "}
                  {booking.trip.destinationLabel.split(",")[0]}
                </p>
                <Badge tone={booking.status === "confirmed" ? "green" : "amber"}>
                  {statusLabel(booking.status)}
                </Badge>
                <strong className="booking-total">{money(booking.priceTotal)}</strong>
                <Link href="/account/" className="sh-btn sh-btn-primary sh-btn-md">
                  Xem chuyến của tôi
                </Link>
              </div>
            ) : (
              <>
                <h2>Đặt chuyến</h2>
                <label className="sh-field">
                  <span>Điểm đón</span>
                  <select value={fromId} onChange={(event) => setFromId(event.target.value)}>
                    {pickups.map((stop) => (
                      <option key={stop.id} value={stop.id}>
                        {stop.name}
                      </option>
                    ))}
                  </select>
                </label>
                <label className="sh-field">
                  <span>Điểm trả</span>
                  <select value={toId} onChange={(event) => setToId(event.target.value)}>
                    {dropoffs.map((stop) => (
                      <option key={stop.id} value={stop.id}>
                        {stop.name}
                      </option>
                    ))}
                  </select>
                </label>
                <label className="sh-field">
                  <span>Số ghế</span>
                  <select value={seats} onChange={(event) => setSeats(Number(event.target.value))}>
                    {[1, 2, 3, 4].map((value) => (
                      <option key={value} value={value}>
                        {value} ghế
                      </option>
                    ))}
                  </select>
                </label>
                <div className="price-breakdown">
                  <span>
                    {from?.name ?? "Điểm đón"} → {to?.name ?? "Điểm trả"}
                  </span>
                  <strong>{money(total)}</strong>
                </div>
                {error ? <p className="form-error">{error}</p> : null}
                <Button
                  size="lg"
                  onClick={submit}
                  disabled={!validRoute || bookingBusy || trip.seatsAvailable < seats}
                >
                  {bookingBusy ? "Đang đặt..." : user ? "Đặt chuyến" : "Đăng nhập để đặt"}
                </Button>
                <p className="fine-print">
                  Thanh toán an toàn · Huỷ linh hoạt theo chính sách hoàn tiền.
                </p>
              </>
            )}
          </Card>
        </aside>
      </div>
    </div>
  );
}

export default function TripPage() {
  return (
    <Suspense fallback={<div className="sh-container page-section">Đang tải...</div>}>
      <TripView />
    </Suspense>
  );
}
