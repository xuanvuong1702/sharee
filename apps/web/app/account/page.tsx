"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import type { Booking } from "@sharee/api-client";
import { Badge, Button, Card, EmptyState } from "@sharee/ui";
import { useAuth } from "@/components/AuthProvider";
import { dateLabel, money, statusLabel, timeLabel } from "@/lib/sharee";

export default function AccountPage() {
  const { api, user, ready } = useAuth();
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [cancelling, setCancelling] = useState<string | null>(null);

  async function cancel(id: string) {
    if (!confirm("Huỷ chuyến này?")) return;
    setCancelling(id);
    try {
      await api.cancelBooking(id);
      setBookings(await api.myBookings());
    } catch (e) {
      setError(e instanceof Error ? e.message : "Không huỷ được chuyến");
    } finally {
      setCancelling(null);
    }
  }

  useEffect(() => {
    if (!user) {
      setLoading(false);
      return;
    }
    setLoading(true);
    api
      .myBookings()
      .then((items) => setBookings(items))
      .catch((err) => setError(err instanceof Error ? err.message : "Không tải được chuyến"))
      .finally(() => setLoading(false));
  }, [api, user]);

  return (
    <div className="sh-container page-section">
      <div className="page-heading">
        <div>
          <span className="sh-eyebrow">TÀI KHOẢN</span>
          <h1>Chuyến của tôi</h1>
          <p>Quản lý vé và lịch trình đã đặt.</p>
        </div>
        <Link href="/#tim-chuyen" className="sh-btn sh-btn-ghost sh-btn-md">
          Đặt chuyến mới
        </Link>
      </div>

      {!ready || loading ? (
        <div className="shimmer card-skeleton" />
      ) : !user ? (
        <Card>
          <EmptyState
            title="Bạn chưa đăng nhập"
            message="Đăng nhập để xem chuyến đã đặt và nhận thông báo."
          />
          <div className="center-actions">
            <Link href="/login/?next=/account/" className="sh-btn sh-btn-primary sh-btn-lg">
              Đăng nhập
            </Link>
          </div>
        </Card>
      ) : error ? (
        <Card>
          <EmptyState title="Không tải được chuyến" message={error} />
        </Card>
      ) : bookings.length === 0 ? (
        <Card>
          <EmptyState
            title="Chưa có chuyến nào"
            message="Đặt chuyến đầu tiên để bắt đầu hành trình của bạn."
          />
          <div className="center-actions">
            <Link href="/#tim-chuyen" className="sh-btn sh-btn-primary sh-btn-md">
              Tìm chuyến
            </Link>
          </div>
        </Card>
      ) : (
        <div className="bookings-list">
          {bookings.map((booking, index) => (
            <Card key={booking.id} className="booking-row air-account-row">
              <div className="air-account-img"
                style={{ backgroundImage: `url(${["/images/vietnam-road.jpg", "/images/hanoi.jpg", "/images/vietnam-city.jpg"][index % 3]})` }} />
              <div className={`booking-status-bar ${booking.status}`} />
              <div className="booking-row-main">
                <div className="booking-row-head">
                  <Badge tone={booking.status === "completed" ? "blue" : booking.status === "confirmed" ? "green" : "amber"}>
                    {statusLabel(booking.status)}
                  </Badge>
                  <span className="muted">
                    {dateLabel(booking.trip.departureTime)} · {timeLabel(booking.trip.departureTime)}
                  </span>
                </div>
                <h3>
                  {booking.trip.originLabel.split(",")[0]} → {booking.trip.destinationLabel.split(",")[0]}
                </h3>
                <p className="muted">
                  {booking.seats} ghế · {booking.driver.fullName} · {booking.trip.vehicle} ·{" "}
                  {booking.trip.plate}
                </p>
              </div>
              <div className="booking-row-side">
                <strong>{money(booking.priceTotal)}</strong>
                <span>{booking.payment?.status === "succeeded" ? "Đã thanh toán" : "Chưa thanh toán"}</span>
                {["pending_payment", "pending_driver", "confirmed"].includes(booking.status) ? (
                  <Button variant="ghost" size="sm" disabled={cancelling === booking.id}
                    onClick={() => cancel(booking.id)}>
                    {cancelling === booking.id ? "Đang huỷ..." : "Huỷ chuyến"}
                  </Button>
                ) : null}
              </div>
            </Card>
          ))}
          <p className="fine-print">
            Chat, theo dõi trực tiếp và tip tài xế hiện có đầy đủ trên app Android/iOS.
          </p>
        </div>
      )}
    </div>
  );
}
