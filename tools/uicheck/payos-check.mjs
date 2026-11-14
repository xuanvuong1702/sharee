import crypto from 'crypto';

const main = 'http://localhost:8080';
const payosApi = 'http://localhost:18082';
const checksumKey = 'test-checksum-key-0123456789';

async function login(phone) {
  const otp = await fetch(`${main}/api/auth/otp/request`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ phone }),
  }).then((r) => r.json());
  return fetch(`${main}/api/auth/otp/verify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ phone, code: otp.devCode }),
  }).then((r) => r.json());
}

const auth = await login('+84912345678');
const headers = { 'Content-Type': 'application/json', Authorization: `Bearer ${auth.accessToken}` };
const search = await fetch(
  `${main}/api/trips/search?fromLat=21.0285&fromLng=105.7749&toLat=20.8449&toLng=106.6881&date=2026-11-15&seats=1`,
  { headers },
).then((r) => r.json());
const trip = search.items[0];
const booking = await fetch(`${main}/api/trips/${trip.tripId}/bookings`, {
  method: 'POST',
  headers: { ...headers, 'Idempotency-Key': `payos-${Date.now()}` },
  body: JSON.stringify({ seats: 1, fromStopId: trip.pickupStop.id, toStopId: trip.dropoffStop.id }),
}).then((r) => r.json());

const checkout = await fetch(`${payosApi}/api/bookings/${booking.id}/payos`, {
  method: 'POST',
  headers,
}).then((r) => r.json());
if (!checkout.checkoutUrl) throw new Error(`No checkout: ${JSON.stringify(checkout)}`);

const data = {
  orderCode: checkout.orderCode,
  amount: checkout.amount,
  description: checkout.description,
  accountNumber: '0000000001',
  reference: `FT${Date.now()}`,
  transactionDateTime: new Date().toISOString(),
  currency: 'VND',
  paymentLinkId: checkout.paymentLinkId,
  code: '00',
  desc: 'success',
};
const canonical = Object.keys(data)
  .sort()
  .map((key) => `${key}=${data[key]}`)
  .join('&');
const signature = crypto.createHmac('sha256', checksumKey).update(canonical).digest('hex');

const webhook = await fetch(`${payosApi}/api/payments/payos/webhook`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ code: '00', desc: 'success', data, signature }),
});
if (!webhook.ok) throw new Error(`Webhook failed ${webhook.status}: ${await webhook.text()}`);

const updated = await fetch(`${main}/api/bookings/${booking.id}`, { headers }).then((r) => r.json());
if (updated.status !== 'confirmed') throw new Error(`Booking not confirmed: ${updated.status}`);
if (updated.payment?.status !== 'succeeded') throw new Error('Payment not succeeded');

console.log(`PAYOS CHECKOUT OK: ${checkout.checkoutUrl}`);
console.log(`PAYOS WEBHOOK OK: booking=${updated.status} payment=${updated.payment.status}`);
