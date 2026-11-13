param(
    [string]$BaseUrl = "http://localhost:8080",
    [string]$Phone = "+84912345678",
    [int]$Seats = 2,
    [int]$Requests = 6
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Net.Http

function Login([string]$phone) {
    $otp = Invoke-RestMethod "$BaseUrl/api/auth/otp/request" -Method Post -ContentType "application/json" `
        -Body (@{ phone = $phone } | ConvertTo-Json)
    $auth = Invoke-RestMethod "$BaseUrl/api/auth/otp/verify" -Method Post -ContentType "application/json" `
        -Body (@{ phone = $phone; code = $otp.devCode } | ConvertTo-Json)
    return @{ Authorization = "Bearer $($auth.accessToken)" }
}

$passenger = Login $Phone
$date = (Get-Date).AddDays(1).ToString("yyyy-MM-dd")
$search = Invoke-RestMethod "$BaseUrl/api/trips/search?fromLat=21.0285&fromLng=105.7749&toLat=20.8449&toLng=106.6881&date=$date&seats=$Seats" `
    -Headers $passenger
$trip = $search.items | Where-Object { $_.seatsAvailable -ge $Seats } | Select-Object -First 1
if (-not $trip) { throw "No trip with enough seats" }

$initial = [int]$trip.seatsAvailable
$expected = [math]::Floor($initial / $Seats)
Write-Host "Trip $($trip.tripId): $initial seats, sending $Requests concurrent requests for $Seats seats. Expected max $expected success."

$client = New-Object System.Net.Http.HttpClient
$client.DefaultRequestHeaders.Authorization =
    [System.Net.Http.Headers.AuthenticationHeaderValue]::new("Bearer", $passenger.Authorization.Substring(7))

$tasks = @()
for ($i = 0; $i -lt $Requests; $i++) {
    $body = @{ seats = $Seats; fromStopId = $trip.pickupStop.id; toStopId = $trip.dropoffStop.id } | ConvertTo-Json
    $request = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Post,
        "$BaseUrl/api/trips/$($trip.tripId)/bookings")
    $request.Headers.Add("Idempotency-Key", "oversell-$i-$(Get-Random)")
    $request.Content = New-Object System.Net.Http.StringContent($body, [System.Text.Encoding]::UTF8, "application/json")
    $tasks += $client.SendAsync($request)
}

[System.Threading.Tasks.Task]::WaitAll($tasks)
$codes = $tasks | ForEach-Object { [int]$_.Result.StatusCode }
$ok = ($codes | Where-Object { $_ -eq 201 }).Count
$conflict = ($codes | Where-Object { $_ -eq 409 }).Count

$after = Invoke-RestMethod "$BaseUrl/api/trips/$($trip.tripId)" -Headers $passenger
Write-Host "Result: 201=$ok, 409=$conflict, seats_left=$($after.seatsAvailable)"

if ($after.seatsAvailable -lt 0) { throw "FAIL: negative seats" }
if ($ok -ne $expected) { throw "FAIL: success count $ok != expected $expected" }
Write-Host "OVERSELL TEST PASSED" -ForegroundColor Green
