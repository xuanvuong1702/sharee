"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { LocationFields, type TripPlace } from "./LocationFields";
import { nextDate } from "@/lib/sharee";

type Panel = "places" | "date" | "seats" | null;

function dateAfter(days: number) {
  const d = new Date(Date.now() + days * 86_400_000);
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Ho_Chi_Minh" }).format(d);
}

export function AirbnbSearchBar({
  initialPickup = null,
  initialDropoff = null,
  initialDate,
  initialSeats = 1,
}: {
  initialPickup?: TripPlace | null;
  initialDropoff?: TripPlace | null;
  initialDate?: string;
  initialSeats?: number;
} = {}) {
  const router = useRouter();
  const rootRef = useRef<HTMLDivElement>(null);
  const [panel, setPanel] = useState<Panel>(null);
  const [pickup, setPickup] = useState<TripPlace | null>(initialPickup);
  const [dropoff, setDropoff] = useState<TripPlace | null>(initialDropoff);
  const [date, setDate] = useState(initialDate || nextDate());
  const [seats, setSeats] = useState(initialSeats);

  useEffect(() => {
    function onDown(event: MouseEvent) {
      if (panel && rootRef.current && !rootRef.current.contains(event.target as Node)) {
        setPanel(null);
      }
    }
    function onKey(event: KeyboardEvent) {
      if (event.key === "Escape") setPanel(null);
    }
    document.addEventListener("mousedown", onDown);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onDown);
      document.removeEventListener("keydown", onKey);
    };
  }, [panel]);

  const locationValue = pickup && dropoff
    ? `${pickup.label.split(",")[0]} → ${dropoff.label.split(",")[0]}`
    : pickup
      ? `Từ ${pickup.label.split(",")[0]}`
      : "Chọn điểm";

  const shortDate = new Intl.DateTimeFormat("vi-VN", {
    day: "2-digit", month: "2-digit",
  }).format(new Date(`${date}T00:00:00+07:00`));

  const now = new Date();
  const todayValue = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Ho_Chi_Minh",
  }).format(now);
  const months = [0, 1].map((offset) => {
    const first = new Date(now.getFullYear(), now.getMonth() + offset, 1);
    const days = new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate();
    const cells: Array<string | null> = Array(first.getDay()).fill(null);
    for (let day = 1; day <= days; day++) {
      cells.push(`${first.getFullYear()}-${String(first.getMonth() + 1).padStart(2, "0")}-${String(day).padStart(2, "0")}`);
    }
    return {
      title: new Intl.DateTimeFormat("vi-VN", { month: "long", year: "numeric" }).format(first),
      cells,
    };
  });

  const search = () => {
    if (!pickup || !dropoff) { setPanel("places"); return; }
    const params = new URLSearchParams({
      fromLat: String(pickup.lat), fromLng: String(pickup.lng),
      toLat: String(dropoff.lat), toLng: String(dropoff.lng),
      fromLabel: pickup.label, toLabel: dropoff.label,
      date, seats: String(seats),
    });
    setPanel(null);
    router.push(`/search/?${params.toString()}`);
  };

  return (
    <div className="airbnb-search" ref={rootRef}>
      <div className={`airbnb-pill ${panel ? "open" : ""}`}>
        <button type="button"
          className={`airbnb-seg places ${panel === "places" ? "active" : ""}`}
          onClick={() => setPanel(panel === "places" ? null : "places")}>
          <span className="airbnb-label">Địa điểm</span>
          <span className="airbnb-value">{locationValue}</span>
        </button>
        <span className="airbnb-divider" />
        <button type="button"
          className={`airbnb-seg date ${panel === "date" ? "active" : ""}`}
          onClick={() => setPanel(panel === "date" ? null : "date")}>
          <span className="airbnb-label">Khi nào</span>
          <span className="airbnb-value">{shortDate}</span>
        </button>
        <span className="airbnb-divider" />
        <button type="button"
          className={`airbnb-seg seats ${panel === "seats" ? "active" : ""}`}
          onClick={() => setPanel(panel === "seats" ? null : "seats")}>
          <span className="airbnb-label">Với ai</span>
          <span className="airbnb-value">{seats} ghế</span>
        </button>
        <button type="button" className="airbnb-search-btn"
          onClick={search} aria-label="Tìm chuyến">
          <span aria-hidden="true">→</span>
        </button>
      </div>

      {panel && (
        <div className="airbnb-panel">
          {panel === "places" && (
            <>
              <div className="airbnb-panel-head">
                <strong>Bạn muốn đi đâu?</strong>
                <button type="button" onClick={() => setPanel(null)} aria-label="Đóng">×</button>
              </div>
              <LocationFields
                pickup={pickup}
                dropoff={dropoff}
                onChange={(kind, place) => kind === "pickup" ? setPickup(place) : setDropoff(place)}
                compact
              />
              <div className="airbnb-panel-foot">
                <button type="button" className="airbnb-clear" onClick={() => {
                  setPickup(null); setDropoff(null);
                }}>Xoá</button>
                <button type="button" className="airbnb-done" onClick={() => setPanel(null)}>
                  Xong
                </button>
              </div>
            </>
          )}
          {panel === "date" && (
            <>
              <div className="airbnb-panel-head">
                <strong>Khi nào bạn muốn đi?</strong>
                <button type="button" onClick={() => setPanel(null)} aria-label="Đóng">×</button>
              </div>
              <div className="airbnb-calendar">
                {months.map((month) => (
                  <div key={month.title} className="airbnb-month">
                    <strong>{month.title}</strong>
                    <div className="airbnb-weekdays">
                      {["CN", "T2", "T3", "T4", "T5", "T6", "T7"].map((d) => <span key={d}>{d}</span>)}
                    </div>
                    <div className="airbnb-days">
                      {month.cells.map((value, index) => value ? (
                        <button key={value} type="button"
                          className={`${value === date ? "selected" : ""} ${value < todayValue ? "disabled" : ""}`}
                          disabled={value < todayValue}
                          onClick={() => setDate(value)}>{Number(value.slice(-2))}</button>
                      ) : <span key={`empty-${index}`} />)}
                    </div>
                  </div>
                ))}
              </div>
              <div className="airbnb-date-quick">
                {[["Hôm nay", 0], ["Ngày mai", 1], ["Cuối tuần", 3]].map(([label, days]) => (
                  <button key={String(label)} type="button"
                    className={date === dateAfter(Number(days)) ? "active" : ""}
                    onClick={() => setDate(dateAfter(Number(days)))}>{label}</button>
                ))}
              </div>
              <div className="airbnb-panel-foot">
                <span className="airbnb-date-summary">Đã chọn: {shortDate}</span>
                <button type="button" className="airbnb-done" onClick={() => setPanel(null)}>Xong</button>
              </div>
            </>
          )}
          {panel === "seats" && (
            <>
              <div className="airbnb-panel-head">
                <strong>Bạn đi với ai?</strong>
                <button type="button" onClick={() => setPanel(null)} aria-label="Đóng">×</button>
              </div>
              <p className="airbnb-muted">Chọn số ghế cần đặt. Tối đa 4 ghế mỗi lần.</p>
              <div className="airbnb-stepper">
                <div>
                  <strong>Số ghế</strong>
                  <small>Bao gồm bạn</small>
                </div>
                <div className="airbnb-stepper-controls">
                  <button type="button" onClick={() => setSeats(Math.max(1, seats - 1))}
                    disabled={seats <= 1} aria-label="Giảm ghế">−</button>
                  <span>{seats}</span>
                  <button type="button" onClick={() => setSeats(Math.min(4, seats + 1))}
                    disabled={seats >= 4} aria-label="Tăng ghế">+</button>
                </div>
              </div>
              <div className="airbnb-panel-foot">
                <button type="button" className="airbnb-done" onClick={() => setPanel(null)}>Xong</button>
              </div>
            </>
          )}
        </div>
      )}
    </div>
  );
}
