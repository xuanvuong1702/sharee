export const API_URL =
  process.env.NEXT_PUBLIC_API_URL?.replace(/\/$/, "") || "http://localhost:8080";

export type RoutePreset = {
  id: string;
  name: string;
  fromLabel: string;
  fromLat: number;
  fromLng: number;
  toLabel: string;
  toLat: number;
  toLng: number;
};

export const routePresets: RoutePreset[] = [
  {
    id: "hanoi-haiphong",
    name: "Hà Nội → Hải Phòng",
    fromLabel: "Bến xe Mỹ Đình, Hà Nội",
    fromLat: 21.0285,
    fromLng: 105.7749,
    toLabel: "Lạch Tray, Hải Phòng",
    toLat: 20.8449,
    toLng: 106.6881,
  },
  {
    id: "hanoi-noibai",
    name: "Hà Nội → Nội Bài",
    fromLabel: "Bến xe Mỹ Đình, Hà Nội",
    fromLat: 21.0285,
    fromLng: 105.7749,
    toLabel: "Sân bay Nội Bài",
    toLat: 21.2187,
    toLng: 105.7999,
  },
];

export const money = (value: number) =>
  `${new Intl.NumberFormat("vi-VN").format(value)}đ`;

export const dateLabel = (value: string) =>
  new Intl.DateTimeFormat("vi-VN", {
    weekday: "short",
    day: "2-digit",
    month: "2-digit",
    timeZone: "Asia/Ho_Chi_Minh",
  }).format(new Date(`${value.slice(0, 10)}T00:00:00+07:00`));

export const timeLabel = (value: string) =>
  new Intl.DateTimeFormat("vi-VN", {
    hour: "2-digit",
    minute: "2-digit",
    timeZone: "Asia/Ho_Chi_Minh",
  }).format(new Date(value));

export const nextDate = () => {
  const date = new Date(Date.now() + 86_400_000);
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Ho_Chi_Minh",
  }).format(date);
};

export const statusLabel = (status: string) => {
  const labels: Record<string, string> = {
    pending_payment: "Chờ thanh toán",
    pending_driver: "Chờ tài xế",
    confirmed: "Đã xác nhận",
    completed: "Hoàn thành",
    cancelled_by_passenger: "Khách huỷ",
    cancelled_by_driver: "Tài xế huỷ",
    rejected: "Bị từ chối",
  };
  return labels[status] ?? status;
};
