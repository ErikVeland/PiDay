# Store submission checklist (PiDay)

This repo contains:
- **iOS app** (SwiftUI): `PiDay/` + widgets + watch app
- **Android app** (Kotlin/Compose): `PiDayAndroid/`
- **Marketing site** (Next.js): `website/` (includes `/privacy` and `/support`)

## 1) App Store (iOS) — review readiness

### ✅ In-repo items already present
- Privacy manifest: `PiDay/PrivacyInfo.xcprivacy` (and matching widget/watch privacy manifests)
- Versioning in Xcode project:
  - `MARKETING_VERSION = 1.3`
  - `CURRENT_PROJECT_VERSION = 4`

### You still must confirm in App Store Connect
- **Privacy Policy URL**: use `https://piday.glasscode.academy/privacy`
- **Support URL**: use `https://piday.glasscode.academy/support`
- **App Review Information**:
  - Contact info
  - Notes (confirm: no login required, no special hardware, any test account if ever added)
- **App Privacy** (Data Collection): confirm “No data collected” (matches current privacy policy)
  - Note: the app can perform **live lookups** (e.g., for free search and for dates outside the bundled year range) against third-party endpoints (`*.pisearch.joshkeegan.co.uk`, `api.pi.delivery`). Confirm whether any transmitted queries are considered “collected” by you or the third party, and update disclosures if needed.
- **Encryption**: answer export compliance questions (most apps: “does not use encryption beyond OS-provided”)
- **Screenshots**: required for all device classes you support (iPhone + iPad; Mac if distributing to macOS)

### Build + upload (needs macOS)
On a Mac with Xcode installed:
1. Run native validation:
   ```bash
   ./Scripts/native_quality_gate.sh
   ```
2. Archive + upload (Xcode Organizer):
   - Product → Archive
   - Distribute → App Store Connect → Upload

## 2) Play Store (Android) — review readiness

### ✅ In-repo items now present
- Release signing scaffold: `PiDayAndroid/keystore.properties.example`
- Launcher icons + manifest wiring:
  - `PiDayAndroid/app/src/main/AndroidManifest.xml` now points at `@mipmap/ic_launcher`
  - Generated icons in `res/mipmap-*`
 - Android versioning in `PiDayAndroid/gradle.properties`:
   - `PIDAY_ANDROID_VERSION_NAME=1.3`
   - `PIDAY_ANDROID_VERSION_CODE=13`

### Required Play Console items (outside the repo)
- **Privacy Policy URL**: `https://piday.glasscode.academy/privacy`
- **Support URL / contact email**: `https://piday.glasscode.academy/support`
- **Data safety form**: should match “No data collected” (verify Android app does not add analytics/ads)
  - Note: the Android app may also perform live lookups; ensure the Data safety form and privacy policy match actual network behavior.
- **Content rating** questionnaire
- **Store listing** (short description, full description, screenshots, feature graphic)

### Build an AAB (needs Java + Android SDK)
On a machine with JDK 17 + Android SDK installed:
1. Copy signing config:
   ```bash
   cp PiDayAndroid/keystore.properties.example PiDayAndroid/keystore.properties
   # edit keystore.properties with your keystore path + passwords
   ```
2. Build:
   ```bash
   cd PiDayAndroid
   ./gradlew bundleRelease
   ```
3. Upload the resulting `.aab` from:
   - `PiDayAndroid/app/build/outputs/bundle/release/app-release.aab`

## 3) Common “review rejection” checks

- **No dead links**: App Store / Play Store listing URLs must work.
- **No placeholder text**: “TODO”, “lorem ipsum”, sample emails, etc.
- **Privacy claims match behavior**:
  - If you add analytics, ads, crash reporting, etc., update privacy policy + disclosures.
- **Permissions**:
  - Only request what you need.
  - Provide clear in-app context before any permission prompt (if you add any in future).
