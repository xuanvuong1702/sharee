-- Demo data. Times are UTC; Asia/Ho_Chi_Minh is UTC+7.
INSERT INTO users (id, phone, email, full_name, bio, role, verified_level, rating_avg, rating_count) VALUES
  ('11111111-1111-1111-1111-111111111111', '+84900000001', 'admin@sharee.vn', 'Quản trị Sharee', 'Vận hành nền tảng', 'admin', 3, 5.00, 0),
  ('22222222-2222-2222-2222-222222222222', '+84912345678', 'minh@example.com', 'Minh Nguyễn', 'Đi làm Hà Nội – Hải Phòng mỗi cuối tuần.', 'user', 2, 4.90, 12),
  ('33333333-3333-3333-3333-333333333333', '+84912000001', 'kien@example.com', 'Trung Kiên', 'Tài xế tuyến Hà Nội – Hải Phòng.', 'user', 3, 4.90, 128),
  ('44444444-4444-4444-4444-444444444444', '+84912000002', 'hang@example.com', 'Minh Hằng', 'Thích đi du lịch, thường đi tuyến Hà Nội – Hải Phòng.', 'user', 2, 4.80, 64),
  ('55555555-5555-5555-5555-555555555555', '+84912000003', 'linh@example.com', 'Linh Hoàng', 'Sinh viên, hay đi Hà Nội – Hải Phòng.', 'user', 1, 4.90, 3),
  ('66666666-6666-6666-6666-666666666666', '+84912000004', 'hung@example.com', 'Việt Hùng', 'Đi công tác thường xuyên.', 'user', 1, 5.00, 1),
  ('77777777-7777-7777-7777-777777777777', '+84912000005', 'phong@example.com', 'Quốc Phong', 'Tài xế xe 4 chỗ.', 'user', 2, 5.00, 12)
ON CONFLICT (phone) DO NOTHING;

INSERT INTO vehicles (id, owner_id, make, model, year, color, plate, seats, status) VALUES
  ('a1111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'Toyota', 'Vios', 2020, 'Trắng', '30A-123.45', 4, 'active'),
  ('a2222222-2222-2222-2222-222222222222', '44444444-4444-4444-4444-444444444444', 'Honda', 'City', 2019, 'Đen', '30A-678.90', 5, 'active'),
  ('a3333333-3333-3333-3333-333333333333', '77777777-7777-7777-7777-777777777777', 'Hyundai', 'Accent', 2021, 'Bạc', '30A-111.22', 4, 'active')
ON CONFLICT DO NOTHING;

INSERT INTO user_verifications (user_id, type, status, document_ref, reviewed_by, reviewed_at) VALUES
  ('33333333-3333-3333-3333-333333333333', 'id', 'approved', 'seed/cccd-kien.jpg', '11111111-1111-1111-1111-111111111111', now()),
  ('33333333-3333-3333-3333-333333333333', 'license', 'approved', 'seed/gplx-kien.jpg', '11111111-1111-1111-1111-111111111111', now()),
  ('55555555-5555-5555-5555-555555555555', 'id', 'pending', 'seed/cccd-linh.jpg', NULL, NULL);

-- Trips: Hà Nội -> Hải Phòng
INSERT INTO trips (id, driver_id, vehicle_id, origin, destination, origin_label, destination_label, route,
  distance_m, duration_s, departure_time, arrive_estimate, price_per_seat, seats_total, seats_available,
  booking_mode, luggage, pets_allowed, smoking_allowed, status)
VALUES
  ('bbbbbbbb-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333',
   'a1111111-1111-1111-1111-111111111111',
   ST_SetSRID(ST_MakePoint(105.7749, 21.0285), 4326)::geography,
   ST_SetSRID(ST_MakePoint(106.6881, 20.8449), 4326)::geography,
   'Bến xe Mỹ Đình, Hà Nội', 'Lạch Tray, Hải Phòng',
   ST_GeogFromText('SRID=4326;LINESTRING(105.7749 21.0285, 105.8150 21.0004, 106.1000 20.9500, 106.4000 20.9000, 106.6881 20.8449)'),
   105000, 6000,
   (date_trunc('day', now() AT TIME ZONE 'Asia/Ho_Chi_Minh') + interval '1 day 15 hours 30 minutes') AT TIME ZONE 'Asia/Ho_Chi_Minh',
   (date_trunc('day', now() AT TIME ZONE 'Asia/Ho_Chi_Minh') + interval '1 day 17 hours 10 minutes') AT TIME ZONE 'Asia/Ho_Chi_Minh',
   180000, 4, 3, 'instant', true, true, false, 'open'),
  ('bbbbbbbb-2222-2222-2222-222222222222', '44444444-4444-4444-4444-444444444444',
   'a2222222-2222-2222-2222-222222222222',
   ST_SetSRID(ST_MakePoint(105.8150, 21.0004), 4326)::geography,
   ST_SetSRID(ST_MakePoint(106.6881, 20.8449), 4326)::geography,
   'Royal City, Hà Nội', 'Ngã 5 Sân bay Cát Bi, Hải Phòng',
   ST_GeogFromText('SRID=4326;LINESTRING(105.8150 21.0004, 106.1000 20.9500, 106.4000 20.9000, 106.6881 20.8449)'),
   108000, 6300,
   (date_trunc('day', now() AT TIME ZONE 'Asia/Ho_Chi_Minh') + interval '1 day 16 hours') AT TIME ZONE 'Asia/Ho_Chi_Minh',
   (date_trunc('day', now() AT TIME ZONE 'Asia/Ho_Chi_Minh') + interval '1 day 17 hours 45 minutes') AT TIME ZONE 'Asia/Ho_Chi_Minh',
   160000, 4, 4, 'manual', true, false, false, 'open'),
  ('bbbbbbbb-3333-3333-3333-333333333333', '77777777-7777-7777-7777-777777777777',
   'a3333333-3333-3333-3333-333333333333',
   ST_SetSRID(ST_MakePoint(105.7800, 20.9800), 4326)::geography,
   ST_SetSRID(ST_MakePoint(106.7000, 20.8600), 4326)::geography,
   'Big C Thăng Long, Hà Nội', 'Vincom Plaza, Hải Phòng',
   ST_GeogFromText('SRID=4326;LINESTRING(105.7800 20.9800, 106.1000 20.9500, 106.4000 20.9000, 106.7000 20.8600)'),
   112000, 6600,
   (date_trunc('day', now() AT TIME ZONE 'Asia/Ho_Chi_Minh') + interval '1 day 17 hours 15 minutes') AT TIME ZONE 'Asia/Ho_Chi_Minh',
   (date_trunc('day', now() AT TIME ZONE 'Asia/Ho_Chi_Minh') + interval '1 day 19 hours 5 minutes') AT TIME ZONE 'Asia/Ho_Chi_Minh',
   150000, 4, 4, 'instant', true, true, false, 'open'),
  ('bbbbbbbb-4444-4444-4444-444444444444', '33333333-3333-3333-3333-333333333333',
   'a1111111-1111-1111-1111-111111111111',
   ST_SetSRID(ST_MakePoint(105.7749, 21.0285), 4326)::geography,
   ST_SetSRID(ST_MakePoint(105.7999, 21.2187), 4326)::geography,
   'Bến xe Mỹ Đình, Hà Nội', 'Sân bay Nội Bài',
   ST_GeogFromText('SRID=4326;LINESTRING(105.7749 21.0285, 105.7900 21.1000, 105.7999 21.2187)'),
   32000, 2700,
   (date_trunc('day', now() AT TIME ZONE 'Asia/Ho_Chi_Minh') + interval '2 days 8 hours') AT TIME ZONE 'Asia/Ho_Chi_Minh',
   (date_trunc('day', now() AT TIME ZONE 'Asia/Ho_Chi_Minh') + interval '2 days 8 hours 45 minutes') AT TIME ZONE 'Asia/Ho_Chi_Minh',
   90000, 4, 4, 'instant', true, false, false, 'open')
ON CONFLICT DO NOTHING;

-- Stops for trip 1
INSERT INTO trip_stops (id, trip_id, seq, name, location, eta_offset_min, allow_pickup, allow_dropoff, price_from_origin) VALUES
  ('cccccccc-1111-1111-1111-111111111111', 'bbbbbbbb-1111-1111-1111-111111111111', 0, 'Bến xe Mỹ Đình — cổng 2',
   ST_SetSRID(ST_MakePoint(105.7749, 21.0285), 4326)::geography, 0, true, true, 0),
  ('cccccccc-1111-1111-1111-222222222222', 'bbbbbbbb-1111-1111-1111-111111111111', 1, 'Royal City — cổng B',
   ST_SetSRID(ST_MakePoint(105.8150, 21.0004), 4326)::geography, 12, true, false, 90000),
  ('cccccccc-1111-1111-1111-333333333333', 'bbbbbbbb-1111-1111-1111-111111111111', 2, 'Lạch Tray, Hải Phòng',
   ST_SetSRID(ST_MakePoint(106.6881, 20.8449), 4326)::geography, 100, false, true, 180000)
ON CONFLICT DO NOTHING;

INSERT INTO trip_stops (id, trip_id, seq, name, location, eta_offset_min, allow_pickup, allow_dropoff, price_from_origin) VALUES
  ('cccccccc-2222-2222-2222-111111111111', 'bbbbbbbb-2222-2222-2222-222222222222', 0, 'Royal City — cổng B',
   ST_SetSRID(ST_MakePoint(105.8150, 21.0004), 4326)::geography, 0, true, true, 0),
  ('cccccccc-2222-2222-2222-222222222222', 'bbbbbbbb-2222-2222-2222-222222222222', 1, 'Ngã 5 Sân bay Cát Bi',
   ST_SetSRID(ST_MakePoint(106.6881, 20.8449), 4326)::geography, 105, false, true, 160000)
ON CONFLICT DO NOTHING;

INSERT INTO trip_stops (id, trip_id, seq, name, location, eta_offset_min, allow_pickup, allow_dropoff, price_from_origin) VALUES
  ('cccccccc-3333-3333-3333-111111111111', 'bbbbbbbb-3333-3333-3333-333333333333', 0, 'Big C Thăng Long',
   ST_SetSRID(ST_MakePoint(105.7800, 20.9800), 4326)::geography, 0, true, true, 0),
  ('cccccccc-3333-3333-3333-222222222222', 'bbbbbbbb-3333-3333-3333-333333333333', 1, 'Vincom Plaza Hải Phòng',
   ST_SetSRID(ST_MakePoint(106.7000, 20.8600), 4326)::geography, 110, false, true, 150000)
ON CONFLICT DO NOTHING;

INSERT INTO trip_stops (id, trip_id, seq, name, location, eta_offset_min, allow_pickup, allow_dropoff, price_from_origin) VALUES
  ('cccccccc-4444-4444-4444-111111111111', 'bbbbbbbb-4444-4444-4444-444444444444', 0, 'Bến xe Mỹ Đình',
   ST_SetSRID(ST_MakePoint(105.7749, 21.0285), 4326)::geography, 0, true, true, 0),
  ('cccccccc-4444-4444-4444-222222222222', 'bbbbbbbb-4444-4444-4444-444444444444', 1, 'Sân bay Nội Bài — ga đi',
   ST_SetSRID(ST_MakePoint(105.7999, 21.2187), 4326)::geography, 45, false, true, 90000)
ON CONFLICT DO NOTHING;

-- Daily: one line in Ho Chi Minh City
INSERT INTO partners (id, name, type, currency, status) VALUES
  ('dddddddd-1111-1111-1111-111111111111', 'RideShare City', 'collectivite', 'VND', 'active')
ON CONFLICT DO NOTHING;

INSERT INTO lines (id, partner_id, name, brand, description, route, status) VALUES
  ('eeeeeeee-1111-1111-1111-111111111111', 'dddddddd-1111-1111-1111-111111111111',
   'Tuyến 01 · Bến Thành – Suối Tiên', 'RideShare Line',
   'Tuyến đi chung xe buổi sáng và chiều, không cần đặt trước.',
   ST_GeogFromText('SRID=4326;LINESTRING(106.6980 10.7725, 106.7100 10.7950, 106.7250 10.8150, 106.7500 10.8500, 106.7800 10.8620, 106.8020 10.8670)'),
   'active')
ON CONFLICT DO NOTHING;

INSERT INTO line_stops (id, line_id, seq, name, location, qr_token) VALUES
  ('ffffffff-1111-1111-1111-111111111111', 'eeeeeeee-1111-1111-1111-111111111111', 0, 'Bến Thành', ST_SetSRID(ST_MakePoint(106.6980, 10.7725), 4326)::geography, 'BT-01'),
  ('ffffffff-2222-2222-2222-222222222222', 'eeeeeeee-1111-1111-1111-111111111111', 1, 'Bình Thạnh', ST_SetSRID(ST_MakePoint(106.7100, 10.7950), 4326)::geography, 'BT-02'),
  ('ffffffff-3333-3333-3333-333333333333', 'eeeeeeee-1111-1111-1111-111111111111', 2, 'Bến xe Miền Đông', ST_SetSRID(ST_MakePoint(106.7250, 10.8150), 4326)::geography, 'BT-03'),
  ('ffffffff-4444-4444-4444-444444444444', 'eeeeeeee-1111-1111-1111-111111111111', 3, 'Thủ Đức', ST_SetSRID(ST_MakePoint(106.7500, 10.8500), 4326)::geography, 'BT-04'),
  ('ffffffff-5555-5555-5555-555555555555', 'eeeeeeee-1111-1111-1111-111111111111', 4, 'Đại học Quốc gia', ST_SetSRID(ST_MakePoint(106.7800, 10.8620), 4326)::geography, 'BT-05'),
  ('ffffffff-6666-6666-6666-666666666666', 'eeeeeeee-1111-1111-1111-111111111111', 5, 'Suối Tiên', ST_SetSRID(ST_MakePoint(106.8020, 10.8670), 4326)::geography, 'BT-06')
ON CONFLICT DO NOTHING;

INSERT INTO line_service_windows (line_id, weekday, start_time, end_time, headway_min) VALUES
  ('eeeeeeee-1111-1111-1111-111111111111', 1, '06:00', '09:00', 8),
  ('eeeeeeee-1111-1111-1111-111111111111', 2, '06:00', '09:00', 8),
  ('eeeeeeee-1111-1111-1111-111111111111', 3, '06:00', '09:00', 8),
  ('eeeeeeee-1111-1111-1111-111111111111', 4, '06:00', '09:00', 8),
  ('eeeeeeee-1111-1111-1111-111111111111', 5, '06:00', '09:00', 8),
  ('eeeeeeee-1111-1111-1111-111111111111', 1, '16:30', '19:30', 10),
  ('eeeeeeee-1111-1111-1111-111111111111', 2, '16:30', '19:30', 10),
  ('eeeeeeee-1111-1111-1111-111111111111', 3, '16:30', '19:30', 10),
  ('eeeeeeee-1111-1111-1111-111111111111', 4, '16:30', '19:30', 10),
  ('eeeeeeee-1111-1111-1111-111111111111', 5, '16:30', '19:30', 10)
ON CONFLICT DO NOTHING;

INSERT INTO subsidy_rules (partner_id, line_id, per_km_minor, min_amount_minor, max_amount_minor, monthly_cap_minor, effective_from) VALUES
  ('dddddddd-1111-1111-1111-111111111111', 'eeeeeeee-1111-1111-1111-111111111111', 10, 150, 300, 15000, current_date)
ON CONFLICT DO NOTHING;

INSERT INTO reports (reporter_id, target_type, target_id, reason, description, status) VALUES
  ('55555555-5555-5555-5555-555555555555', 'trip', 'bbbbbbbb-2222-2222-2222-222222222222', 'Tài xế đến muộn', 'Chờ 25 phút tại điểm hẹn.', 'open')
ON CONFLICT DO NOTHING;
