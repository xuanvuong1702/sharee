param(
    [string]$BaseUrl = "http://localhost:8080",
    [string]$PassengerPhone = "+84912345678",
    [string]$DriverPhone = "+84912000001"
)

$ErrorActionPreference = "Stop"

function Login([string]$phone) {
    $otp = Invoke-RestMethod "$BaseUrl/api/auth/otp/request" -Method Post -ContentType "application/json" `
        -Body (@{ phone = $phone } | ConvertTo-Json)
    if (-not $otp.devCode) { throw "OTP devCode không có. Bật Auth:ExposeOtp." }
    $auth = Invoke-RestMethod "$BaseUrl/api/auth/otp/verify" -Method Post -ContentType "application/json" `
        -Body (@{ phone = $phone; code = $otp.devCode } | ConvertTo-Json)
    return @{ Authorization = "Bearer $($auth.accessToken)" }
}

Write-Host "1. Health..."
$health = Invoke-RestMethod "$BaseUrl/health"
if ($health.status -ne "ok") { throw "API không khoẻ" }

Write-Host "2. Đăng nhập hành khách..."
$passenger = Login $PassengerPhone

Write-Host "3. Tìm chuyến Hà Nội -> Hải Phòng ngày mai..."
$date = (Get-Date).AddDays(1).ToString("yyyy-MM-dd")
$search = Invoke-RestMethod "$BaseUrl/api/trips/search?fromLat=21.0285&fromLng=105.7749&toLat=20.8449&toLng=106.6881&date=$date&seats=1" `
    -Headers $passenger
if ($search.count -eq 0) { throw "Không có chuyến để test" }
$trip = $search.items[0]
Write-Host "   $($search.count) chuyến, chọn $($trip.tripId)"

Write-Host "4. Đặt 1 ghế..."
$booking = Invoke-RestMethod "$BaseUrl/api/trips/$($trip.tripId)/bookings" -Method Post `
    -Headers @{ Authorization = $passenger.Authorization; "Idempotency-Key" = "smoke-$(Get-Random)" } `
    -ContentType "application/json" `
    -Body (@{ seats = 1; fromStopId = $trip.pickupStop.id; toStopId = $trip.dropoffStop.id } | ConvertTo-Json)
Write-Host "   booking $($booking.id) / $($booking.status)"

Write-Host "5. Thanh toán..."
$paid = Invoke-RestMethod "$BaseUrl/api/bookings/$($booking.id)/pay" -Method Post `
    -Headers $passenger -ContentType "application/json" -Body "{}"
if ($paid.status -ne "confirmed") { throw "Thanh toán không xác nhận" }
Write-Host "   $($paid.status) / $($paid.payment.status)"

Write-Host "6. Chat..."
$threads = Invoke-RestMethod "$BaseUrl/api/conversations" -Headers $passenger
$message = Invoke-RestMethod "$BaseUrl/api/conversations/$($threads[0].id)/messages" -Method Post `
    -Headers $passenger -ContentType "application/json; charset=utf-8" `
    -Body ([Text.Encoding]::UTF8.GetBytes((@{ body = "Smoke test: chào tài xế." } | ConvertTo-Json)))
Write-Host "   gửi: $($message.body)"

Write-Host "7. Vé Daily..."
$lines = Invoke-RestMethod "$BaseUrl/api/daily/lines?lat=10.7725&lng=106.6980" -Headers $passenger
$line = Invoke-RestMethod "$BaseUrl/api/daily/lines/$($lines[0].id)" -Headers $passenger
$ticket = Invoke-RestMethod "$BaseUrl/api/daily/e-tickets" -Method Post -Headers $passenger `
    -ContentType "application/json" `
    -Body (@{ lineId = $line.id; stopId = $line.stops[0].id } | ConvertTo-Json)

Write-Host "8. Tài xế nhận và xác nhận vé..."
$driver = Login $DriverPhone
Invoke-RestMethod "$BaseUrl/api/daily/e-tickets/$($ticket.id)/assign" -Method Post `
    -Headers $driver -ContentType "application/json" -Body "{}" | Out-Null
$validated = Invoke-RestMethod "$BaseUrl/api/daily/e-tickets/$($ticket.id)/validate" -Method Post `
    -Headers $driver -ContentType "application/json" -Body (@{ code = $ticket.code } | ConvertTo-Json)
Write-Host "   $($validated.status) / thưởng $($validated.amountMinor) cent"

Write-Host "SMOKE TEST PASSED" -ForegroundColor Green
