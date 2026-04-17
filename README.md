# PiDay

Find your date in the digits of famous constants.

PiDay ships with bundled ten-year digit indexes (2026–2035) for multiple numbers (π, τ, e, φ, Planck). Pick a date and see how early it appears — plus a calendar heat map for every day.

Available on the [App Store](https://apps.apple.com/app/piday/id6740270587) · [piday.glasscode.academy](https://piday.glasscode.academy)

---

## Repository layout

```
PiDay/               — iOS app (SwiftUI, iOS 17+)
PiDayAndroid/        — Android port (Kotlin + Jetpack Compose) ← work in progress
PiDayWidget/         — iOS home/lock screen widgets
PiDayWatchApp/       — watchOS companion
website/             — Marketing site (Next.js)
Scripts/             — Data pipeline scripts (Python/Swift)
```

---

## iOS app

### Requirements

- macOS 14+
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Build

```bash
# Generate the Xcode project (it's gitignored — regenerate whenever project.yml changes)
xcodegen generate

# Build
xcodebuild -scheme PiDay -configuration Debug build

# Run tests
xcodebuild -scheme PiDay -configuration Debug test \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Then open `PiDay.xcodeproj` in Xcode and run on a simulator or device.

### Architecture

MVVM with SwiftUI. `@Observable` (Swift 5.9) throughout — no `ObservableObject` / `@Published`.

Key layers:

| Layer | What it does |
|---|---|
| `Core/Repository` | Bundled-only lookups across featured numbers via JSON indexes (2026–2035) |
| `Core/Domain` | Pure value types — `DateFormatOption`, `PiMatch`, `CalendarModels`, etc. |
| `Features/Main/AppViewModel` | All search state, navigation, and caching |
| `Services/PreferencesStore` | Appearance settings (theme, font, accent colour) |

See [`CLAUDE.md`](CLAUDE.md) for a full architecture walkthrough.

---

## Android port

The Android port mirrors the iOS feature set exactly. It uses Kotlin 2.1 + Jetpack Compose (Material 3), with the same MVVM structure and repository pattern.

**Stack:** Kotlin 2.1 · Jetpack Compose BOM 2025.05 · ViewModel + StateFlow · Ktor 3.x · kotlinx.serialization · DataStore Preferences · min SDK 26 (Android 8)

### Requirements

- Android Studio Meerkat (2024.3) or later
- Android SDK (installed automatically by Android Studio)
- A device or emulator running Android 8+ (API 26+)

### Build

```bash
cd PiDayAndroid
./gradlew assembleDebug
```

Or open `PiDayAndroid/` in Android Studio and press Run.

### Current status

The core port is complete. What's implemented:

- [x] Bundled index lookup (2026–2035) for featured numbers: π / τ / e / φ / Planck
- [x] All date formats + Search Format Preference
- [x] Calendar heat map sheet
- [x] Digit canvas with highlighted date sequence
- [x] Detail sheet
- [x] Nerdy Stats 2.0
- [x] Date Battles
- [x] Preferences screen (themes, font style, digit size)
- [x] Saved Dates leaderboard (sorting, ranking, label editing)
- [x] Share styles (Classic, Nerd, Battle text share flows)

What still needs Android-specific polish (good first targets for a new contributor):

- [ ] Visual card export — render shareable images instead of text-only share flows
- [ ] Home screen widget (AppWidget / Glance)
- [x] Play Store release build + signing config scaffold
- [ ] Notification (annual featured-day reminders)

### Android release build

The Android app version is tracked in `PiDayAndroid/gradle.properties`:

- `PIDAY_ANDROID_VERSION_CODE`
- `PIDAY_ANDROID_VERSION_NAME`

To produce a signed release build, copy `PiDayAndroid/keystore.properties.example` to `PiDayAndroid/keystore.properties`, fill in your keystore values, and then run:

```bash
cd PiDayAndroid
./gradlew bundleRelease
```

Use `bundleRelease` for the Play Store AAB. `assembleRelease` is still useful for a quick APK smoke test. If `keystore.properties` is absent, Gradle still builds the unsigned release variant so CI and local validation can run without secrets.

### Contributing

If you're joining to help with the Android port:

1. Fork the repo and create a feature branch off `main`
2. Open `PiDayAndroid/` as the project root in Android Studio (not the repo root)
3. The iOS `CLAUDE.md` documents the design decisions behind the app — the Android code mirrors that structure, so it's worth a read even if you're only touching Kotlin
4. PRs against `main` — one feature or fix per PR, please

---

## Pi index data pipeline

The bundled resource `PiDayAndroid/app/src/main/res/raw/pi_2026_2035_index.json` (and its iOS counterpart) covers years 2026–2035, precomputed offline against 5 billion digits.

To regenerate:
1. `Scripts/generate_exact_index.py` — queries the Pi Search API for all date sequences
2. `Scripts/generate_pi_index.swift` — processes raw matches into the structured JSON

## Featured-number digit indexes (Tau / e / Phi / Planck)

The app ships with bundled indexes for each featured number. Each mode looks for the same date strings, but in a different digit stream (π, τ, e, φ, Planck). If a given index is not present in the app bundle, the UI shows an "index unavailable" state for that mode (no fake data).

Generated resource names (iOS `PiDay/Resources/`, Android `app/src/main/res/raw/`):

- `tau_2026_2035_index.json`
- `e_2026_2035_index.json`
- `phi_2026_2035_index.json`
- `planck_2026_2035_index.json`

To generate (examples):

```bash
# Euler's number (e) via pisearch.org
python3 Scripts/generate_featured_number_index.py \
  --featured e \
  --start-year 2026 --end-year 2035 \
  --output PiDay/Resources/e_2026_2035_index.json

# Phi via pisearch.org
python3 Scripts/generate_featured_number_index.py \
  --featured phi \
  --start-year 2026 --end-year 2035 \
  --output PiDay/Resources/phi_2026_2035_index.json

# Tau requires a local digits file (digits after the decimal point).
pip install pyahocorasick --break-system-packages
python3 Scripts/generate_featured_number_index.py \
  --featured tau \
  --digits-file /path/to/tau_digits.txt \
  --start-year 2026 --end-year 2035 \
  --output PiDay/Resources/tau_2026_2035_index.json

# Planck uses a generated digit stream (exact rational h in eV·s mantissa)
python3 Scripts/generate_featured_number_index.py \
  --featured planck \
  --planck-digits 500000000 \
  --start-year 2026 --end-year 2035 \
  --output PiDay/Resources/planck_2026_2035_index.json
```

---

## License

MIT
