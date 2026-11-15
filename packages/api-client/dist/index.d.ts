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
export type SearchParams = {
  fromLat: number;
  fromLng: number;
  toLat: number;
  toLng: number;
  date: string;
  seats: number;
};
export declare class ApiError extends Error {
  status: number;
  constructor(message: string, status: number);
}
export declare class ShareeApi {
  constructor(baseUrl: string, token?: string);
  setToken(token?: string): void;
  requestOtp(phone: string): Promise<{ expiresInSeconds: number; devCode?: string | null }>;
  verifyOtp(phone: string, code: string): Promise<AuthResult>;
  me(): Promise<ShareeUser>;
  search(params: SearchParams): Promise<{ items: SearchResult[]; count: number }>;
  trip(id: string): Promise<Trip>;
  createBooking(tripId: string, seats: number, fromStopId: string, toStopId: string): Promise<Booking>;
  pay(bookingId: string): Promise<Booking>;
  booking(id: string): Promise<Booking>;
  myBookings(): Promise<Booking[]>;
}
