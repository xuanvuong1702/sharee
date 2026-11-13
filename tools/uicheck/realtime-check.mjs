import { HubConnectionBuilder, LogLevel } from '@microsoft/signalr';

const base = 'http://localhost:8080';

async function login(phone) {
  const otp = await fetch(`${base}/api/auth/otp/request`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ phone }),
  }).then((r) => r.json());
  return fetch(`${base}/api/auth/otp/verify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ phone, code: otp.devCode }),
  }).then((r) => r.json());
}

async function waitFor(fn, timeout = 8000) {
  const start = Date.now();
  while (Date.now() - start < timeout) {
    const value = await fn();
    if (value) return value;
    await new Promise((r) => setTimeout(r, 100));
  }
  throw new Error('timeout');
}

const passenger = await login('+84912345678');
const driver = await login('+84912000001');
const pHeaders = { 'Content-Type': 'application/json', Authorization: `Bearer ${passenger.accessToken}` };

const search = await fetch(
  `${base}/api/trips/search?fromLat=21.0285&fromLng=105.7749&toLat=20.8449&toLng=106.6881&date=2026-11-15&seats=1`,
  { headers: pHeaders },
).then((r) => r.json());
const trip = search.items.find((t) => t.seatsAvailable >= 1);
if (!trip) throw new Error('no trip');

async function book() {
  return fetch(`${base}/api/trips/${trip.tripId}/bookings`, {
    method: 'POST',
    headers: { ...pHeaders, 'Idempotency-Key': `rt-${Date.now()}` },
    body: JSON.stringify({ seats: 1, fromStopId: trip.pickupStop.id, toStopId: trip.dropoffStop.id }),
  }).then((r) => r.json());
}

const booking = await book();
await fetch(`${base}/api/bookings/${booking.id}/pay`, {
  method: 'POST',
  headers: pHeaders,
  body: '{}',
});
const conversations = await fetch(`${base}/api/conversations`, { headers: pHeaders }).then((r) => r.json());
const conversation = conversations[0];
if (!conversation) throw new Error('no conversation');

const chat = new HubConnectionBuilder()
  .withUrl(`${base}/hubs/chat`, { accessTokenFactory: () => driver.accessToken })
  .configureLogging(LogLevel.None)
  .build();
let received = null;
chat.on('message', (message) => {
  received = message;
});
await chat.start();
await chat.invoke('JoinConversation', conversation.id);

const bodyText = `realtime-${Date.now()}`;
await fetch(`${base}/api/conversations/${conversation.id}/messages`, {
  method: 'POST',
  headers: pHeaders,
  body: JSON.stringify({ body: bodyText }),
});
const message = await waitFor(() => received);
if (message.body !== bodyText) throw new Error('wrong message');

const history = await fetch(`${base}/api/conversations/${conversation.id}/messages`, {
  headers: pHeaders,
}).then((r) => r.json());
if (!history.some((m) => m.body === bodyText)) throw new Error('message not persisted');

const notifications = new HubConnectionBuilder()
  .withUrl(`${base}/hubs/notifications`, { accessTokenFactory: () => driver.accessToken })
  .configureLogging(LogLevel.None)
  .build();
let notification = null;
notifications.on('notification', (value) => {
  notification = value;
});
await notifications.start();

await book();
const note = await waitFor(() => notification, 10000);

console.log(`CHAT REALTIME OK: ${message.body}`);
console.log(`PERSISTED OK: ${history.length} messages`);
console.log(`NOTIFICATION REALTIME OK: ${note.title}`);

await chat.stop();
await notifications.stop();
