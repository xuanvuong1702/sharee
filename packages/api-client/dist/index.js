export class ApiError extends Error {
    status;
    constructor(message, status) {
        super(message);
        this.status = status;
    }
}
export class ShareeApi {
    baseUrl;
    token;
    constructor(baseUrl, token) {
        this.baseUrl = baseUrl;
        this.token = token;
    }
    setToken(token) {
        this.token = token;
    }
    async request(path, init) {
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
        let body = null;
        try {
            body = text ? JSON.parse(text) : null;
        }
        catch {
            body = text;
        }
        if (!res.ok) {
            const message = body && typeof body === "object" && "error" in body
                ? String(body.error)
                : `Lỗi ${res.status}`;
            throw new ApiError(message, res.status);
        }
        return body;
    }
    requestOtp(phone) {
        return this.request("/api/auth/otp/request", { method: "POST", body: JSON.stringify({ phone }) });
    }
    verifyOtp(phone, code) {
        return this.request("/api/auth/otp/verify", {
            method: "POST",
            body: JSON.stringify({ phone, code }),
        });
    }
    me() {
        return this.request("/api/me");
    }
    search(params) {
        const q = new URLSearchParams({
            fromLat: String(params.fromLat),
            fromLng: String(params.fromLng),
            toLat: String(params.toLat),
            toLng: String(params.toLng),
            date: params.date,
            seats: String(params.seats),
        });
        return this.request(`/api/trips/search?${q}`);
    }
    trip(id) {
        return this.request(`/api/trips/${id}`);
    }
    createBooking(tripId, seats, fromStopId, toStopId) {
        return this.request(`/api/trips/${tripId}/bookings`, {
            method: "POST",
            headers: { "Idempotency-Key": `web-${Date.now()}-${Math.random().toString(36).slice(2)}` },
            body: JSON.stringify({ seats, fromStopId, toStopId }),
        });
    }
    pay(bookingId) {
        return this.request(`/api/bookings/${bookingId}/pay`, {
            method: "POST",
            body: "{}",
        });
    }
    paymentConfig() {
        return this.request("/api/payments/config");
    }
    createPayOs(bookingId) {
        return this.request(`/api/bookings/${bookingId}/payos`, {
            method: "POST",
            body: "{}",
        });
    }
    cancelBooking(bookingId) {
        return this.request(`/api/bookings/${bookingId}/cancel`, {
            method: "POST",
            body: "{}",
        });
    }
    createRide(payload) {
        return this.request("/api/rides", {
            method: "POST",
            body: JSON.stringify(payload),
        });
    }
    ride(id) {
        return this.request(`/api/rides/${id}`);
    }
    cancelRide(id) {
        return this.request(`/api/rides/${id}/cancel`, {
            method: "POST",
            body: JSON.stringify({ reason: "web_cancel" }),
        });
    }
    booking(id) {
        return this.request(`/api/bookings/${id}`);
    }
    myBookings() {
        return this.request("/api/bookings/mine");
    }
}
