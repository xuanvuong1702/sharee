"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Badge, Button, Card } from "@sharee/ui";
import { useAuth } from "@/components/AuthProvider";
import { LocationFields, type TripPlace } from "@/components/LocationFields";

const classes = [
  { id: "bike", label: "Xe máy", desc: "Nhanh, tiết kiệm", icon: "🛵" },
  { id: "car4", label: "Xe 4 chỗ", desc: "Đi gia đình, hành lý", icon: "🚗" },
  { id: "car7", label: "Xe 7 chỗ", desc: "Nhóm đông, nhiều đồ", icon: "🚙" },
];

export default function RidePage() {
  const { api, user, ready } = useAuth();
  const [pickup, setPickup] = useState<TripPlace | null>(null);
  const [dropoff, setDropoff] = useState<TripPlace | null>(null);
  const [vehicleClass, setVehicleClass] = useState("car4");
  const [note, setNote] = useState("");
  const [ride, setRide] = useState<Record<string, unknown> | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!ride) return;
    const id = String(ride.id);
    const timer = setInterval(async () => {
      try {
        const next = await api.ride(id);
        setRide(next);
        if (["completed", "cancelled", "expired"].includes(String(next.status))) {
          clearInterval(timer);
        }
      } catch { /* keep last state */ }
    }, 3000);
    return () => clearInterval(timer);
  }, [api, ride?.id]);

  async function request() {
    if (!user) { window.location.href = "/login/?next=/ride/"; return; }
    if (!pickup || !dropoff) { setError("Chọn điểm đón và điểm đến."); return; }
    setBusy(true); setError("");
    try {
      const created = await api.createRide({
        pickupLabel: pickup.label, pickupLat: pickup.lat, pickupLng: pickup.lng,
        dropoffLabel: dropoff.label, dropoffLat: dropoff.lat, dropoffLng: dropoff.lng,
        vehicleClass, paymentMethod: "cash", note: note.trim() || undefined,
      });
      setRide(created);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Không tạo được chuyến xe.");
    } finally {
      setBusy(false);
    }
  }

  async function cancel() {
    if (!ride) return;
    try { setRide(await api.cancelRide(String(ride.id))); }
    catch (e) { setError(e instanceof Error ? e.message : "Không huỷ được chuyến."); }
  }

  if (ride) {
    const status = String(ride.status ?? "searching");
    const driver = ride.driver as Record<string, unknown> | null | undefined;
    return (
      <div className="sh-container page-section">
        <div className="page-heading">
          <div>
            <span className="sh-eyebrow">ĐẶT XE</span>
            <h1>Đang tìm tài xế</h1>
            <p>{String(ride.pickupLabel)} → {String(ride.dropoffLabel)}</p>
          </div>
        </div>
        <div className="ride-status-grid">
          <Card className="ride-status-card">
            <Badge tone={status === "completed" ? "green" : "amber"}>{status}</Badge>
            <h2>{status === "searching" ? "Đang kết nối tài xế..." : "Chuyến xe của bạn"}</h2>
            <p>Thanh toán trực tiếp cho tài xế khi hoàn tất. Không trừ tiền trong ứng dụng.</p>
            {driver ? (
              <div className="ride-driver">
                <span className="avatar large">{String(driver.fullName ?? "T").slice(0, 1)}</span>
                <div>
                  <strong>{String(driver.fullName ?? "Tài xế")}</strong>
                  <small>{String(driver.vehicleLabel ?? driver.plate ?? "")}</small>
                </div>
              </div>
            ) : null}
            {["searching", "accepted", "arrived"].includes(status) ? (
              <Button variant="ghost" onClick={cancel}>Huỷ chuyến</Button>
            ) : null}
            <Link href="/ride/" className="sh-btn sh-btn-ghost sh-btn-md"
              onClick={() => setRide(null)}>Đặt chuyến khác</Link>
          </Card>
          <Card className="ride-tips">
            <h3>Trong lúc chờ</h3>
            <p>Giữ điện thoại bên mình. Tài xế sẽ gọi khi đến điểm hẹn.</p>
            <p>Kiểm tra biển số và tên tài xế trước khi lên xe.</p>
            <Link href="/account/">Xem chuyến của tôi →</Link>
          </Card>
        </div>
        {error && <div className="error">{error}</div>}
      </div>
    );
  }

  return (
    <div className="sh-container page-section">
      <div className="page-heading">
        <div>
          <span className="sh-eyebrow">ĐẶT XE</span>
          <h1>Đặt xe đi ngay</h1>
          <p>Tài xế gần bạn · thanh toán trực tiếp · không cần chờ ghép chuyến.</p>
        </div>
      </div>
      <div className="ride-layout">
        <Card className="ride-form-card">
          <LocationFields
            pickup={pickup}
            dropoff={dropoff}
            onChange={(kind, place) => kind === "pickup" ? setPickup(place) : setDropoff(place)}
          />
          <div className="ride-classes">
            {classes.map((item) => (
              <button key={item.id} type="button"
                className={`ride-class ${vehicleClass === item.id ? "active" : ""}`}
                onClick={() => setVehicleClass(item.id)}>
                <span>{item.icon}</span>
                <strong>{item.label}</strong>
                <small>{item.desc}</small>
              </button>
            ))}
          </div>
          <label className="sh-field"><span>Ghi chú cho tài xế</span>
            <input value={note} onChange={(e) => setNote(e.target.value)}
              placeholder="Ví dụ: tôi có 2 vali..." maxLength={200} />
          </label>
          {error && <div className="error">{error}</div>}
          <Button size="lg" onClick={request} disabled={busy || !ready || !pickup || !dropoff}>
            {busy ? "Đang tạo chuyến..." : "Tìm tài xế"}
          </Button>
          <p className="fine-print">Giá cước do tài xế và bạn thống nhất trực tiếp.</p>
        </Card>
        <Card className="ride-side">
          <h3>Vì sao đặt xe trên Sharee?</h3>
          <ul>
            <li>Tài xế đã xác thực danh tính.</li>
            <li>Không giữ tiền, không phí ẩn.</li>
            <li>Huỷ trước khi tài xế đến.</li>
          </ul>
        </Card>
      </div>
    </div>
  );
}
