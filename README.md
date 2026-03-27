# PiDay

Find your birthday in the digits of Pi.

PiDay searches up to 5 billion decimal places of π for any date you choose, shows you where it first appears, and displays a calendar heat map of how early every day of the year shows up.

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
| `Core/Repository` | Routes lookups to the bundled JSON index (2026–2035) or the live Pi Search API |
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

- [x] Bundled index lookup (`pi_2026_2035_index.json`)
- [x] Live API fallback for out-of-range dates (Ktor)
- [x] All date formats + Search Format Preference
- [x] Calendar heat map sheet
- [x] Pi canvas with highlighted date sequence
- [x] Detail sheet
- [x] Preferences screen (themes, font style, digit size)
- [x] Saved dates
- [x] Free search (arbitrary digit sequence)
- [x] Share card

What still needs Android-specific polish (good first targets for a new contributor):

- [ ] Share card export — `ShareSheet` integration for saving/sharing the PNG
- [ ] Home screen widget (AppWidget / Glance)
- [ ] Play Store release build + signing config
- [ ] Notification (annual Pi Day reminder)

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

---

## License

MIT
