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

## 3. iOS secrets (tuỳ chọn)

Nếu không cấu hình, workflow build **unsigned IPA** để tải artifact (không cài trực tiếp/không TestFlight).

| Secret | Nội dung |
|---|---|
| `IOS_CERTIFICATE_BASE64` | file `.p12` distribution |
| `IOS_CERTIFICATE_PASSWORD` | mật khẩu p12 |
| `IOS_PROVISIONING_PROFILE_BASE64` | file `.mobileprovision` |
| `IOS_KEYCHAIN_PASSWORD` | mật khẩu keychain tạm |
| `IOS_TEAM_ID` | Apple Team ID |
| `IOS_BUNDLE_ID` | bundle id, mặc định `vn.sharee.shareeMobile` |

Nếu đủ secrets, workflow import keychain/profile, build `flutter build ipa --export-method app-store`.

Provisioning profile phải khớp bundle id và certificate.

## 4. TestFlight (tuỳ chọn)

Thêm:

| Secret | Nội dung |
|---|---|
| `APPSTORE_KEY_ID` | App Store Connect API Key ID |
| `APPSTORE_ISSUER_ID` | Issuer ID |
| `APPSTORE_PRIVATE_KEY` | nội dung file `.p8` |

Workflow upload bằng `xcrun altool --upload-app` nếu IPA signed thành công.
Nếu runner/Xcode không hỗ trợ `altool`, thay bằng Transporter/fastlane.

## 5. Firebase config

- Android: `GOOGLE_SERVICES_JSON_BASE64` (secret) → `mobile/android/app/google-services.json`.
- iOS: `GOOGLE_SERVICE_INFO_PLIST_BASE64` (secret) → `mobile/ios/Runner/GoogleService-Info.plist`.

Lưu ý: project chưa bật Gradle plugin `com.google.gms.google-services`; nếu FCM Android cần plugin,
thêm plugin và rebuild. Mobile hiện khởi tạo Firebase bằng `FirebaseOptions` từ dart-defines.

## 6. Phát hành

```bash
git tag v1.0.0
git push origin v1.0.0
```

Workflow sẽ build Android + iOS, upload artifact và tạo GitHub Release.

Kiểm tra local trước khi tag:

```powershell
cd mobile
flutter analyze
flutter test
```

## 7. Lưu ý

- Không commit keystore, `.p8`, `key.properties`, `google-services.json` thật.
- API URL phải HTTPS cho bản phát hành.
- GitHub Release chỉ chạy với tag; manual dispatch chỉ artifact.
- iOS unsigned IPA không dùng để phát hành App Store.
