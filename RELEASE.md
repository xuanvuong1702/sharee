# Auto release Android + iOS trên GitHub Actions

Workflow: [`.github/workflows/release.yml`](.github/workflows/release.yml)

Chạy khi:
- push tag `v*` → build APK/AAB/IPA và tạo GitHub Release;
- `workflow_dispatch` → build artifact, không tạo Release.

## 1. Repository variables

Settings → Secrets and variables → Actions → **Variables**:

| Biến | Bắt buộc | Ví dụ |
|---|---|---|
| `API_BASE_URL` | ✅ | `https://api.example.com` |
| `MAP_TILE_URL` | — | `https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=...` |
| `MAP_ATTRIBUTION` | — | `© MapTiler © OpenStreetMap` |
| `MAP_USER_AGENT` | — | `vn.sharee.mobile` |
| `FIREBASE_API_KEY` | — | Firebase Web API key |
| `FIREBASE_APP_ID` | — | `1:...:android:...` |
| `FIREBASE_MESSAGING_SENDER_ID` | — | `123456789` |
| `FIREBASE_PROJECT_ID` | — | `sharee-prod` |
| `APP_VERSION` | — | `1.0.0` (dùng cho manual dispatch) |
| `IOS_EXPORT_METHOD` | — | `development` (mặc định), `ad-hoc`, `app-store`, `enterprise` |

## 2. Android secrets

| Secret | Nội dung |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | file `.jks`/`.p12` mã hoá base64 |
| `ANDROID_KEYSTORE_PASSWORD` | mật khẩu keystore |
| `ANDROID_KEY_ALIAS` | alias, ví dụ `sharee` |
| `ANDROID_KEY_PASSWORD` | mật khẩu key |

Tạo keystore local:

```powershell
powershell -File scripts/create-keystore.ps1
# file: mobile/android/keystore/sharee-upload.jks
```

Base64:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("mobile/android/keystore/sharee-upload.jks")) | Set-Clipboard
```

Workflow tạo `key.properties` và build:
- `Sharee-<version>-<run>.apk`
- `Sharee-<version>-<run>.aab`

## 3. iOS: chọn cách ký

Nếu **không có** iOS secrets, workflow build **unsigned IPA**. IPA này không cài trực tiếp được, nhưng có thể
dùng Sideloadly/AltStore để ký bằng Apple ID trên máy tính.

Nếu có Apple Developer account, cấu hình secrets và chọn `IOS_EXPORT_METHOD`:

| Giá trị | Dùng khi | Cài lên iPhone |
|---|---|---|
| `development` | Máy iPhone của bạn đã đăng ký trong Apple Developer | Xcode / Apple Configurator 2 |
| `ad-hoc` | Chia cho vài tester đã đăng ký UDID | Diawi, Firebase App Distribution |
| `app-store` | TestFlight / App Store | TestFlight |
| `enterprise` | Apple Enterprise Program | MDM/nội bộ |

Với **một iPhone cá nhân**, dùng `development` là đơn giản nhất.

### Secrets

| Secret | Nội dung |
|---|---|
| `IOS_CERTIFICATE_BASE64` | file `.p12` development hoặc distribution |
| `IOS_CERTIFICATE_PASSWORD` | mật khẩu p12 |
| `IOS_PROVISIONING_PROFILE_BASE64` | file `.mobileprovision` có UDID của iPhone |
| `IOS_KEYCHAIN_PASSWORD` | mật khẩu keychain tạm |
| `IOS_TEAM_ID` | Apple Team ID |
| `IOS_BUNDLE_ID` | bundle id, mặc định `vn.sharee.shareeMobile` |

Provisioning profile phải khớp:
- bundle id;
- certificate;
- UDID của thiết bị (với development/ad-hoc).

Quy trình tạo trên [developer.apple.com](https://developer.apple.com/account):
1. Đăng ký iPhone UDID.
2. Tạo certificate development (hoặc distribution cho ad-hoc).
3. Tạo provisioning profile tương ứng, chọn đúng App ID + certificate + device.
4. Export `.p12` từ Keychain Access và tải `.mobileprovision`.
5. Base64 hai file, lưu vào GitHub Secrets.

## 4. Cài IPA lên iPhone

### Cách A — Apple Configurator 2 (macOS)

1. Cài Apple Configurator 2 từ Mac App Store.
2. Cắm iPhone, bật **Developer Mode** trên iPhone:
   - Settings → Privacy & Security → Developer Mode → On → restart.
3. Mở Apple Configurator 2 → chọn iPhone → **Add → Apps → Choose from my Mac** → chọn file `.ipa`.
4. Trên iPhone vào Settings → General → VPN & Device Management → trust developer certificate.

### Cách B — Xcode (macOS)

1. Mở Xcode → Window → Devices and Simulators.
2. Chọn iPhone → **+** → chọn `.ipa`.
3. Trust certificate trên iPhone.

### Cách C — Ad Hoc qua Diawi/Firebase App Distribution

- Upload IPA ad-hoc lên Diawi hoặc Firebase App Distribution.
- Gửi link cho tester.
- Tester mở link trên iPhone và cài; UDID phải có trong provisioning profile.

### Cách D — Không có Apple Developer Program

Dùng **unsigned IPA** từ GitHub Release:

1. Tải `Sharee-<version>-unsigned.ipa`.
2. Trên Windows/macOS cài **Sideloadly** hoặc **AltStore**.
3. Đăng nhập Apple ID, chọn IPA, ký và cài vào iPhone.
4. Bật Developer Mode và trust certificate.

Lưu ý:
- Apple ID miễn phí: app hết hạn sau **7 ngày**, phải ký lại.
- Apple Developer Program: development/ad-hoc profile dùng được **1 năm** (theo certificate/profile).
- Cần cáp kết nối iPhone với máy tính cho cách A/B/D.

## 5. TestFlight (tuỳ chọn)

Thêm:

| Secret | Nội dung |
|---|---|
| `APPSTORE_KEY_ID` | App Store Connect API Key ID |
| `APPSTORE_ISSUER_ID` | Issuer ID |
| `APPSTORE_PRIVATE_KEY` | nội dung file `.p8` |

Đặt `IOS_EXPORT_METHOD=app-store` để workflow upload bằng `xcrun altool`.
TestFlight không cần đẩy app ra store, nhưng cần Apple Developer Program và App Store Connect.

## 6. Firebase config

- Android: `GOOGLE_SERVICES_JSON_BASE64` (secret) → `mobile/android/app/google-services.json`.
- iOS: `GOOGLE_SERVICE_INFO_PLIST_BASE64` (secret) → `mobile/ios/Runner/GoogleService-Info.plist`.

Lưu ý: project chưa bật Gradle plugin `com.google.gms.google-services`; nếu FCM Android cần plugin,
thêm plugin và rebuild. Mobile hiện khởi tạo Firebase bằng `FirebaseOptions` từ dart-defines.

## 7. Phát hành

```bash
git tag v1.1.1
git push origin v1.1.1
```

Workflow sẽ build Android + iOS, upload artifact và tạo GitHub Release.

Kiểm tra local trước khi tag:

```powershell
cd mobile
flutter analyze
flutter test
```

## 8. Lưu ý

- Không commit keystore, `.p8`, `key.properties`, `google-services.json` thật.
- API URL phải HTTPS cho bản phát hành thật.
- GitHub Release chỉ chạy với tag; manual dispatch chỉ artifact.
- iOS unsigned IPA **không cài trực tiếp** — phải ký lại hoặc dùng signed IPA.
- Apple Developer Program có phí thường niên; Apple ID miễn phí chỉ ký được 7 ngày/lần.
