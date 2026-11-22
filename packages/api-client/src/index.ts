export type ShareeUser = {
  id: string;
  phone: string;
  fullName: string;
  email?: string | null;
  avatarUrl?: string | null;
  bio?: string | null;
  role: string;
  verifiedLevel: number;
  ratingAvg: number;
  ratingCount: number;
};

export type Place = { lat: number; lng: number; label: string };

export type Stop = {
  id: string;
  seq: number;
  name: string;
  lat: number;
  lng: number;
  etaOffsetMin: number;
  allowPickup: boolean;
  allowDropoff: boolean;
  priceFromOrigin: number;
};

export type Vehicle = {
  id: string;
  make: string;
  model: string;
  year?: number | null;
  color?: string | null;
  plate: string;
  seats: number;
  status: string;
};

export type SearchResult = {
  tripId: string;
  driver: ShareeUser;
  vehicle: Vehicle;
  originLabel: string;
  destinationLabel: string;
  departureTime: string;
  arriveEstimate: string;
  pricePerSeat: number;
  seatsAvailable: number;
  pickupStop: Stop;
  dropoffStop: Stop;
  accessMeters: number;
  bookingMode: string;
};

export type Trip = {
  id: string;
  driver: ShareeUser;
  vehicle: Vehicle;
  origin: Place;
  destination: Place;
  departureTime: string;
  arriveEstimate: string;
  pricePerSeat: number;
  seatsTotal: number;
  seatsAvailable: number;
  bookingMode: string;
  luggage: boolean;
  petsAllowed: boolean;
  smokingAllowed: boolean;
  status: string;
  stops: Stop[];
};

export type Payment = {
  id: string;
  bookingId: string;
  amount: number;
  currency: string;
  status: string;
  provider: string;
  capturedAt?: string | null;
};

export type TripSummary = {
  id: string;
  originLabel: string;
  destinationLabel: string;
  departureTime: string;
  driverName: string;
  vehicle: string;
  plate: string;
};

export type Booking = {
  id: string;
  tripId: string;
  passenger: ShareeUser;
  driver: ShareeUser;
  fromStop: Stop;
  toStop: Stop;
  seats: number;
  priceTotal: number;
  status: string;
  expiresAt?: string | null;
  createdAt: string;
  trip: TripSummary;
  payment?: Payment | null;
};

export type AuthResult = { accessToken: string; refreshToken?: string; user: ShareeUser };

export class ApiError extends Error {
  status: number;
  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

export type SearchParams = {
  fromLat: number;
  fromLng: number;
  toLat: number;
  toLng: number;
  date: string;
  seats: number;
};

export class ShareeApi {
  constructor(
    private readonly baseUrl: string,
    private token?: string,
  ) {}

  setToken(token?: string) {
    this.token = token;
  }

  private async request<T>(path: string, init?: RequestInit): Promise<T> {
    const res = await fetch(`${this.baseUrl}${path}`, {
      ...init,
      headers: {
        Accept: "application/json",
        ...(init?.body ? { "Content-Type": "application/json" } : {}),
        ...(this.token ? { Authorization: `Bearer ${this.token}` } : {}),
        ...init?.headers,
      },
      cache: "no-store",
    });
    const text = await res.text();
    let body: unknown = null;
    try {
      body = text ? JSON.parse(text) : null;
    } catch {
      body = text;
    }
    if (!res.ok) {
      const message =
        body && typeof body === "object" && "error" in body
          ? String((body as { error: unknown }).error)
          : `Lỗi ${res.status}`;
      throw new ApiError(message, res.status);
    }
    return body as T;
  }

  requestOtp(phone: string) {
    return this.request<{ expiresInSeconds: number; devCode?: string | null }>(
      "/api/auth/otp/request",
      { method: "POST", body: JSON.stringify({ phone }) },
    );
  }

  verifyOtp(phone: string, code: string) {
    return this.request<AuthResult>("/api/auth/otp/verify", {
      method: "POST",
      body: JSON.stringify({ phone, code }),
    });
  }

  me() {
    return this.request<ShareeUser>("/api/me");
  }

  search(params: SearchParams) {
    const q = new URLSearchParams({
      fromLat: String(params.fromLat),
      fromLng: String(params.fromLng),
      toLat: String(params.toLat),
      toLng: String(params.toLng),
      date: params.date,
      seats: String(params.seats),
    });
    return this.request<{ items: SearchResult[]; count: number }>(`/api/trips/search?${q}`);
  }

  trip(id: string) {
    return this.request<Trip>(`/api/trips/${id}`);
  }

  createBooking(tripId: string, seats: number, fromStopId: string, toStopId: string) {
    return this.request<Booking>(`/api/trips/${tripId}/bookings`, {
      method: "POST",
      headers: { "Idempotency-Key": `web-${Date.now()}-${Math.random().toString(36).slice(2)}` },
      body: JSON.stringify({ seats, fromStopId, toStopId }),
    });
  }

  pay(bookingId: string) {
    return this.request<Booking>(`/api/bookings/${bookingId}/pay`, {
      method: "POST",
      body: "{}",
    });
  }

  paymentConfig() {
    return this.request<{
      provider: string;
      payosEnabled: boolean;
      methods: string[];
    }>("/api/payments/config");
  }

  createPayOs(bookingId: string) {
    return this.request<{
      checkoutUrl: string;
      qrCode: string;
      amount: number;
      orderCode: number;
      expiresAt: string;
    }>(`/api/bookings/${bookingId}/payos`, {
      method: "POST",
      body: "{}",
    });
  }

  cancelBooking(bookingId: string) {
    return this.request<{ status: string }>(`/api/bookings/${bookingId}/cancel`, {
      method: "POST",
      body: "{}",
    });
  }

  booking(id: string) {
    return this.request<Booking>(`/api/bookings/${id}`);
  }

  myBookings() {
    return this.request<Booking[]>("/api/bookings/mine");
  }
}
