param(
    [string]$Password = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$android = Join-Path $root "mobile\android"
$keystoreDir = Join-Path $android "keystore"
$keystore = Join-Path $keystoreDir "sharee-upload.jks"
$properties = Join-Path $android "key.properties"

if (Test-Path $keystore) {
    Write-Host "Keystore already exists: $keystore"
    exit 0
}

if ([string]::IsNullOrWhiteSpace($Password)) {
    $bytes = New-Object byte[] 24
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)
    $rng.Dispose()
    $Password = [Convert]::ToBase64String($bytes).Replace("+", "A").Replace("/", "B").TrimEnd("=")
}

New-Item -ItemType Directory -Force $keystoreDir | Out-Null
& keytool -genkeypair -v `
    -keystore $keystore -storetype JKS `
    -alias sharee -keyalg RSA -keysize 2048 -validity 10000 `
    -storepass $Password -keypass $Password `
    -dname "CN=Sharee, OU=Mobile, O=Sharee, L=Hanoi, C=VN"

@"
storePassword=$Password
keyPassword=$Password
keyAlias=sharee
storeFile=../keystore/sharee-upload.jks
"@ | Set-Content -Encoding ASCII $properties

Write-Host "Created $keystore"
Write-Host "Created $properties (keep private)"
