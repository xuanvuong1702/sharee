# Auto release Android + iOS trÃªn GitHub Actions

Workflow: [`.github/workflows/release.yml`](.github/workflows/release.yml)

Cháº¡y khi:
- push tag `v*` â†’ build APK/AAB/IPA vÃ  táº¡o GitHub Release;
- `workflow_dispatch` â†’ build artifact, khÃ´ng táº¡o Release.

## 1. Repository variables

Settings â†’ Secrets and variables â†’ Actions â†’ **Variables**:

| Biáº¿n | Báº¯t buá»™c | VÃ­ dá»¥ |
|---|---|---|
| `API_BASE_URL` | âœ… | `https://api.example.com` |
| `MAP_TILE_URL` | â€” | `https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=...` |
| `MAP_ATTRIBUTION` | â€” | `Â© MapTiler Â© OpenStreetMap` |
| `MAP_USER_AGENT` | â€” | `vn.sharee.mobile` |
| `FIREBASE_API_KEY` | â€” | Firebase Web API key |
| `FIREBASE_APP_ID` | â€” | `1:...:android:...` |
| `FIREBASE_MESSAGING_SENDER_ID` | â€” | `123456789` |
| `FIREBASE_PROJECT_ID` | â€” | `sharee-prod` |
| `APP_VERSION` | â€” | `1.0.0` (dÃ¹ng cho manual dispatch) |
| `IOS_EXPORT_METHOD` | â€” | `development` (máº·c Ä‘á»‹nh), `ad-hoc`, `app-store`, `enterprise` |

## 2. Android secrets

| Secret | Ná»™i dung |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | file `.jks`/`.p12` mÃ£ hoÃ¡ base64 |
| `ANDROID_KEYSTORE_PASSWORD` | máº­t kháº©u keystore |
| `ANDROID_KEY_ALIAS` | alias, vÃ­ dá»¥ `sharee` |
| `ANDROID_KEY_PASSWORD` | máº­t kháº©u key |

Táº¡o keystore local:

```powershell
powershell -File infra/scripts/create-keystore.ps1
# file: apps/mobile/android/keystore/sharee-upload.jks
```

Base64:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("apps/mobile/android/keystore/sharee-upload.jks")) | Set-Clipboard
```

Workflow táº¡o `key.properties` vÃ  build:
- `Sharee-<version>-<run>.apk`
- `Sharee-<version>-<run>.aab`

## 3. iOS: chá»n cÃ¡ch kÃ½

Náº¿u **khÃ´ng cÃ³** iOS secrets, workflow build **unsigned IPA**. IPA nÃ y khÃ´ng cÃ i trá»±c tiáº¿p Ä‘Æ°á»£c, nhÆ°ng cÃ³ thá»ƒ
dÃ¹ng Sideloadly/AltStore Ä‘á»ƒ kÃ½ báº±ng Apple ID trÃªn mÃ¡y tÃ­nh.

Náº¿u cÃ³ Apple Developer account, cáº¥u hÃ¬nh secrets vÃ  chá»n `IOS_EXPORT_METHOD`:

| GiÃ¡ trá»‹ | DÃ¹ng khi | CÃ i lÃªn iPhone |
|---|---|---|
| `development` | MÃ¡y iPhone cá»§a báº¡n Ä‘Ã£ Ä‘Äƒng kÃ½ trong Apple Developer | Xcode / Apple Configurator 2 |
| `ad-hoc` | Chia cho vÃ i tester Ä‘Ã£ Ä‘Äƒng kÃ½ UDID | Diawi, Firebase App Distribution |
| `app-store` | TestFlight / App Store | TestFlight |
| `enterprise` | Apple Enterprise Program | MDM/ná»™i bá»™ |

Vá»›i **má»™t iPhone cÃ¡ nhÃ¢n**, dÃ¹ng `development` lÃ  Ä‘Æ¡n giáº£n nháº¥t.

### Secrets

| Secret | Ná»™i dung |
|---|---|
| `IOS_CERTIFICATE_BASE64` | file `.p12` development hoáº·c distribution |
| `IOS_CERTIFICATE_PASSWORD` | máº­t kháº©u p12 |
| `IOS_PROVISIONING_PROFILE_BASE64` | file `.mobileprovision` cÃ³ UDID cá»§a iPhone |
| `IOS_KEYCHAIN_PASSWORD` | máº­t kháº©u keychain táº¡m |
| `IOS_TEAM_ID` | Apple Team ID |
| `IOS_BUNDLE_ID` | bundle id, máº·c Ä‘á»‹nh `vn.sharee.shareeMobile` |

Provisioning profile pháº£i khá»›p:
- bundle id;
- certificate;
- UDID cá»§a thiáº¿t bá»‹ (vá»›i development/ad-hoc).

Quy trÃ¬nh táº¡o trÃªn [developer.apple.com](https://developer.apple.com/account):
1. ÄÄƒng kÃ½ iPhone UDID.
2. Táº¡o certificate development (hoáº·c distribution cho ad-hoc).
3. Táº¡o provisioning profile tÆ°Æ¡ng á»©ng, chá»n Ä‘Ãºng App ID + certificate + device.
4. Export `.p12` tá»« Keychain Access vÃ  táº£i `.mobileprovision`.
5. Base64 hai file, lÆ°u vÃ o GitHub Secrets.

## 4. CÃ i IPA lÃªn iPhone

### CÃ¡ch A â€” Apple Configurator 2 (macOS)

1. CÃ i Apple Configurator 2 tá»« Mac App Store.
2. Cáº¯m iPhone, báº­t **Developer Mode** trÃªn iPhone:
   - Settings â†’ Privacy & Security â†’ Developer Mode â†’ On â†’ restart.
3. Má»Ÿ Apple Configurator 2 â†’ chá»n iPhone â†’ **Add â†’ Apps â†’ Choose from my Mac** â†’ chá»n file `.ipa`.
4. TrÃªn iPhone vÃ o Settings â†’ General â†’ VPN & Device Management â†’ trust developer certificate.

### CÃ¡ch B â€” Xcode (macOS)

1. Má»Ÿ Xcode â†’ Window â†’ Devices and Simulators.
2. Chá»n iPhone â†’ **+** â†’ chá»n `.ipa`.
3. Trust certificate trÃªn iPhone.

### CÃ¡ch C â€” Ad Hoc qua Diawi/Firebase App Distribution

- Upload IPA ad-hoc lÃªn Diawi hoáº·c Firebase App Distribution.
- Gá»­i link cho tester.
- Tester má»Ÿ link trÃªn iPhone vÃ  cÃ i; UDID pháº£i cÃ³ trong provisioning profile.

### CÃ¡ch D â€” KhÃ´ng cÃ³ Apple Developer Program

DÃ¹ng **unsigned IPA** tá»« GitHub Release:

1. Táº£i `Sharee-<version>-unsigned.ipa`.
2. TrÃªn Windows/macOS cÃ i **Sideloadly** hoáº·c **AltStore**.
3. ÄÄƒng nháº­p Apple ID, chá»n IPA, kÃ½ vÃ  cÃ i vÃ o iPhone.
4. Báº­t Developer Mode vÃ  trust certificate.

LÆ°u Ã½:
- Apple ID miá»…n phÃ­: app háº¿t háº¡n sau **7 ngÃ y**, pháº£i kÃ½ láº¡i.
- Apple Developer Program: development/ad-hoc profile dÃ¹ng Ä‘Æ°á»£c **1 nÄƒm** (theo certificate/profile).
- Cáº§n cÃ¡p káº¿t ná»‘i iPhone vá»›i mÃ¡y tÃ­nh cho cÃ¡ch A/B/D.

## 5. TestFlight (tuá»³ chá»n)

ThÃªm:

| Secret | Ná»™i dung |
|---|---|
| `APPSTORE_KEY_ID` | App Store Connect API Key ID |
| `APPSTORE_ISSUER_ID` | Issuer ID |
| `APPSTORE_PRIVATE_KEY` | ná»™i dung file `.p8` |

Äáº·t `IOS_EXPORT_METHOD=app-store` Ä‘á»ƒ workflow upload báº±ng `xcrun altool`.
TestFlight khÃ´ng cáº§n Ä‘áº©y app ra store, nhÆ°ng cáº§n Apple Developer Program vÃ  App Store Connect.

## 6. Firebase config

- Android: `GOOGLE_SERVICES_JSON_BASE64` (secret) â†’ `apps/mobile/android/app/google-services.json`.
- iOS: `GOOGLE_SERVICE_INFO_PLIST_BASE64` (secret) â†’ `apps/mobile/ios/Runner/GoogleService-Info.plist`.

LÆ°u Ã½: project chÆ°a báº­t Gradle plugin `com.google.gms.google-services`; náº¿u FCM Android cáº§n plugin,
thÃªm plugin vÃ  rebuild. Mobile hiá»‡n khá»Ÿi táº¡o Firebase báº±ng `FirebaseOptions` tá»« dart-defines.

## 7. PhÃ¡t hÃ nh

```bash
git tag v1.1.1
git push origin v1.1.1
```

Workflow sáº½ build Android + iOS, upload artifact vÃ  táº¡o GitHub Release.

Kiá»ƒm tra local trÆ°á»›c khi tag:

```powershell
cd mobile
flutter analyze
flutter test
```

## 8. LÆ°u Ã½

- KhÃ´ng commit keystore, `.p8`, `key.properties`, `google-services.json` tháº­t.
- API URL pháº£i HTTPS cho báº£n phÃ¡t hÃ nh tháº­t.
- GitHub Release chá»‰ cháº¡y vá»›i tag; manual dispatch chá»‰ artifact.
- iOS unsigned IPA **khÃ´ng cÃ i trá»±c tiáº¿p** â€” pháº£i kÃ½ láº¡i hoáº·c dÃ¹ng signed IPA.
- Apple Developer Program cÃ³ phÃ­ thÆ°á»ng niÃªn; Apple ID miá»…n phÃ­ chá»‰ kÃ½ Ä‘Æ°á»£c 7 ngÃ y/láº§n.

