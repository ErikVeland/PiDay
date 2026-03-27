# PiDay Android Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port PiDay to a native Android app (Kotlin + Jetpack Compose) that is functionally identical to the iOS version, distributed via the Play Store.

**Architecture:** MVVM with Jetpack Compose UI, Kotlin coroutines for async work, and Ktor for HTTP. The structure mirrors iOS exactly: Core/Domain, Core/Data, Core/Repository, Features/*, Services. No Hilt — dependencies are passed manually to keep things simple for a first Android project.

**Tech Stack:** Kotlin 2.1, Jetpack Compose (Material3), ViewModel + StateFlow, Ktor 3.x, kotlinx.serialization, DataStore Preferences

---

## Prerequisites (manual steps before running any task)

1. **Open Android Studio** at `/Applications/Android Studio.app`. On first launch it will run the Setup Wizard — accept all defaults. This installs the Android SDK to `~/Library/Android/sdk`.
2. **Create an emulator (AVD):** In Android Studio → Device Manager → Create Virtual Device → Pixel 8 Pro → API 35 (download if needed) → Finish.
3. **Verify** by running any empty project on the emulator. If you see a "Hello Android" screen, you're ready.

---

## File Structure

```
PiDayAndroid/                          ← new sibling directory in the same repo
├── gradle/
│   └── libs.versions.toml             ← version catalog (all dependency versions in one place)
├── app/
│   ├── build.gradle.kts
│   └── src/
│       ├── main/
│       │   ├── AndroidManifest.xml
│       │   ├── res/
│       │   │   └── raw/
│       │   │       └── pi_2026_2035_index.json   ← copy from iOS resources
│       │   └── java/academy/glasscode/piday/
│       │       ├── MainActivity.kt
│       │       ├── core/
│       │       │   ├── domain/
│       │       │   │   ├── DateFormatOption.kt
│       │       │   │   ├── IndexingConvention.kt
│       │       │   │   ├── SearchFormatPreference.kt
│       │       │   │   ├── PiMatch.kt
│       │       │   │   ├── CalendarModels.kt
│       │       │   │   └── SavedDate.kt
│       │       │   ├── data/
│       │       │   │   ├── DateStringGenerator.kt
│       │       │   │   └── PiIndexPayload.kt
│       │       │   └── repository/
│       │       │       ├── PiRepository.kt
│       │       │       ├── DefaultPiRepository.kt
│       │       │       ├── PiStore.kt
│       │       │       └── PiLiveLookupService.kt
│       │       ├── design/
│       │       │   ├── AppTheme.kt              ← Material3 theme + AppTheme enum
│       │       │   └── PiPalette.kt             ← semantic color tokens
│       │       ├── features/
│       │       │   ├── main/
│       │       │   │   ├── AppViewModel.kt
│       │       │   │   └── MainScreen.kt
│       │       │   ├── canvas/
│       │       │   │   └── PiCanvasView.kt
│       │       │   ├── calendar/
│       │       │   │   └── CalendarSheet.kt
│       │       │   ├── detail/
│       │       │   │   └── DetailSheet.kt
│       │       │   ├── preferences/
│       │       │   │   └── PreferencesScreen.kt
│       │       │   ├── saveддates/
│       │       │   │   └── SavedDatesSheet.kt
│       │       │   ├── freesearch/
│       │       │   │   ├── FreeSearchSheet.kt
│       │       │   │   └── FreeSearchViewModel.kt
│       │       │   └── share/
│       │       │       └── ShareCard.kt
│       │       └── services/
│       │           ├── PreferencesStore.kt
│       │           └── SavedDatesStore.kt
│       └── test/
│           └── java/academy/glasscode/piday/
│               ├── DateStringGeneratorTest.kt
│               ├── DateFormatOptionTest.kt
│               └── PiStoreTest.kt
├── build.gradle.kts
├── settings.gradle.kts
└── gradle.properties
```

---

## Swift → Kotlin Cheat Sheet (read once, reference later)

| Swift | Kotlin |
|-------|--------|
| `struct Foo` | `data class Foo` |
| `enum Foo: String, CaseIterable` | `enum class Foo` |
| `protocol Foo` | `interface Foo` |
| `final class Foo` | `class Foo` (classes are `final` by default) |
| `@MainActor class` | `class FooViewModel : ViewModel()` |
| `@Published var x` | `private val _x = MutableStateFlow(…)`  /  `val x = _x.asStateFlow()` |
| `async func foo()` | `suspend fun foo()` |
| `Task { await foo() }` | `viewModelScope.launch { foo() }` |
| `withThrowingTaskGroup` | `coroutineScope { async { … }.await() }` |
| `URLSession.data(from:)` | `client.get(url).body<T>()` (Ktor) |
| `JSONDecoder().decode()` | `Json.decodeFromString<T>(json)` |
| `UserDefaults` | `DataStore<Preferences>` |
| `Bundle.main.url(forResource:)` | `context.resources.openRawResource(R.raw.name)` |
| `guard let x else { return }` | `val x = … ?: return` |
| `?.` optional chaining | `?.` (identical) |
| `switch` | `when` |

---

## Phase 1: Foundation

### Task 1: Gradle project scaffold

**Files:**
- Create: `PiDayAndroid/settings.gradle.kts`
- Create: `PiDayAndroid/build.gradle.kts`
- Create: `PiDayAndroid/gradle.properties`
- Create: `PiDayAndroid/gradle/libs.versions.toml`
- Create: `PiDayAndroid/app/build.gradle.kts`
- Create: `PiDayAndroid/app/src/main/AndroidManifest.xml`
- Create: `PiDayAndroid/app/src/main/java/academy/glasscode/piday/MainActivity.kt`

- [ ] **Step 1: Create settings.gradle.kts**

```kotlin
// PiDayAndroid/settings.gradle.kts
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "PiDayAndroid"
include(":app")
```

- [ ] **Step 2: Create root build.gradle.kts**

```kotlin
// PiDayAndroid/build.gradle.kts
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.kotlin.serialization) apply false
}
```

- [ ] **Step 3: Create gradle.properties**

```properties
# PiDayAndroid/gradle.properties
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
kotlin.code.style=official
android.nonTransitiveRClass=true
```

- [ ] **Step 4: Create version catalog**

```toml
# PiDayAndroid/gradle/libs.versions.toml
[versions]
agp = "8.8.2"
kotlin = "2.1.0"
coreKtx = "1.15.0"
lifecycle = "2.8.7"
activityCompose = "1.10.1"
composeBom = "2025.03.00"
navigationCompose = "2.8.9"
datastore = "1.1.3"
ktor = "3.1.2"
kotlinxSerialization = "1.8.1"
junit = "4.13.2"
androidxJunit = "1.2.1"
espresso = "3.6.1"

[libraries]
androidx-core-ktx = { group = "androidx.core", name = "core-ktx", version.ref = "coreKtx" }
androidx-lifecycle-runtime-ktx = { group = "androidx.lifecycle", name = "lifecycle-runtime-ktx", version.ref = "lifecycle" }
androidx-lifecycle-viewmodel-compose = { group = "androidx.lifecycle", name = "lifecycle-viewmodel-compose", version.ref = "lifecycle" }
androidx-activity-compose = { group = "androidx.activity", name = "activity-compose", version.ref = "activityCompose" }
androidx-compose-bom = { group = "androidx.compose", name = "compose-bom", version.ref = "composeBom" }
androidx-ui = { group = "androidx.compose.ui", name = "ui" }
androidx-ui-graphics = { group = "androidx.compose.ui", name = "ui-graphics" }
androidx-ui-tooling = { group = "androidx.compose.ui", name = "ui-tooling" }
androidx-ui-tooling-preview = { group = "androidx.compose.ui", name = "ui-tooling-preview" }
androidx-ui-test-manifest = { group = "androidx.compose.ui", name = "ui-test-manifest" }
androidx-ui-test-junit4 = { group = "androidx.compose.ui", name = "ui-test-junit4" }
androidx-material3 = { group = "androidx.compose.material3", name = "material3" }
androidx-navigation-compose = { group = "androidx.navigation", name = "navigation-compose", version.ref = "navigationCompose" }
androidx-datastore-preferences = { group = "androidx.datastore", name = "datastore-preferences", version.ref = "datastore" }
ktor-client-android = { group = "io.ktor", name = "ktor-client-android", version.ref = "ktor" }
ktor-client-content-negotiation = { group = "io.ktor", name = "ktor-client-content-negotiation", version.ref = "ktor" }
ktor-serialization-kotlinx-json = { group = "io.ktor", name = "ktor-serialization-kotlinx-json", version.ref = "ktor" }
kotlinx-serialization-json = { group = "org.jetbrains.kotlinx", name = "kotlinx-serialization-json", version.ref = "kotlinxSerialization" }
junit = { group = "junit", name = "junit", version.ref = "junit" }
androidx-junit = { group = "androidx.test.ext", name = "junit", version.ref = "androidxJunit" }
androidx-espresso-core = { group = "androidx.test.espresso", name = "espresso-core", version.ref = "espresso" }

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
kotlin-android = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
kotlin-compose = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
kotlin-serialization = { id = "org.jetbrains.kotlin.plugin.serialization", version.ref = "kotlin" }
```

- [ ] **Step 5: Create app/build.gradle.kts**

```kotlin
// PiDayAndroid/app/build.gradle.kts
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

android {
    namespace = "academy.glasscode.piday"
    compileSdk = 35

    defaultConfig {
        applicationId = "academy.glasscode.piday.android"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        compose = true
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.datastore.preferences)
    implementation(libs.ktor.client.android)
    implementation(libs.ktor.client.content.negotiation)
    implementation(libs.ktor.serialization.kotlinx.json)
    implementation(libs.kotlinx.serialization.json)

    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.ui.test.junit4)
    debugImplementation(libs.androidx.ui.tooling)
    debugImplementation(libs.androidx.ui.test.manifest)
}
```

- [ ] **Step 6: Create AndroidManifest.xml**

```xml
<!-- PiDayAndroid/app/src/main/AndroidManifest.xml -->
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />

    <application
        android:label="PiDay"
        android:icon="@mipmap/ic_launcher"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:theme="@style/Theme.PiDay"
        android:supportsRtl="true">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

- [ ] **Step 7: Create res/values/themes.xml** (required by manifest)

Create `PiDayAndroid/app/src/main/res/values/themes.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="Theme.PiDay" parent="android:Theme.Material.Light.NoActionBar" />
</resources>
```

- [ ] **Step 8: Create placeholder MainActivity.kt**

```kotlin
// app/src/main/java/academy/glasscode/piday/MainActivity.kt
package academy.glasscode.piday

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            Text("PiDay Android — scaffold ready")
        }
    }
}

@Preview(showBackground = true)
@Composable
fun DefaultPreview() {
    Text("PiDay Android — scaffold ready")
}
```

- [ ] **Step 9: Copy the bundled JSON index**

```bash
mkdir -p PiDayAndroid/app/src/main/res/raw
cp PiDay/Resources/pi_2026_2035_index.json PiDayAndroid/app/src/main/res/raw/pi_2026_2035_index.json
```

- [ ] **Step 10: Open project in Android Studio and sync**

Open `PiDayAndroid/` folder in Android Studio (File → Open → select the folder). Wait for Gradle sync to complete. It will download AGP, Kotlin, Compose, and all libraries (~500MB first time). Fix any SDK version mismatches it prompts for.

- [ ] **Step 11: Verify the app builds and runs**

Press the green Run button (or Shift+F10) with your AVD selected. Expected: emulator opens showing "PiDay Android — scaffold ready".

- [ ] **Step 12: Commit**

```bash
cd PiDayAndroid
git add .
git commit -m "feat(android): Gradle scaffold, placeholder MainActivity, bundled pi index"
```

---

### Task 2: Domain models

**Files:**
- Create: `app/src/main/java/academy/glasscode/piday/core/domain/DateFormatOption.kt`
- Create: `app/src/main/java/academy/glasscode/piday/core/domain/IndexingConvention.kt`
- Create: `app/src/main/java/academy/glasscode/piday/core/domain/SearchFormatPreference.kt`
- Create: `app/src/main/java/academy/glasscode/piday/core/domain/PiMatch.kt`
- Create: `app/src/main/java/academy/glasscode/piday/core/domain/CalendarModels.kt`
- Create: `app/src/main/java/academy/glasscode/piday/core/domain/SavedDate.kt`
- Test: `app/src/test/java/academy/glasscode/piday/DateFormatOptionTest.kt`

- [ ] **Step 1: Write the failing test**

```kotlin
// app/src/test/java/academy/glasscode/piday/DateFormatOptionTest.kt
package academy.glasscode.piday

import academy.glasscode.piday.core.domain.DateFormatOption
import org.junit.Assert.assertEquals
import org.junit.Test

class DateFormatOptionTest {
    @Test fun displayNames() {
        assertEquals("YYYYMMDD", DateFormatOption.YYYYMMDD.displayName)
        assertEquals("DDMMYYYY", DateFormatOption.DDMMYYYY.displayName)
        assertEquals("MMDDYYYY", DateFormatOption.MMDDYYYY.displayName)
        assertEquals("YYMMDD",   DateFormatOption.YYMMDD.displayName)
        assertEquals("D/M/YYYY", DateFormatOption.DMY_NO_LEADING_ZEROS.displayName)
    }

    @Test fun queryPartsYyyymmdd() {
        val parts = DateFormatOption.YYYYMMDD.queryParts("20260314")
        assertEquals("14", parts.day)
        assertEquals("03", parts.month)
        assertEquals("2026", parts.year)
    }

    @Test fun queryPartsDdmmyyyy() {
        val parts = DateFormatOption.DDMMYYYY.queryParts("14032026")
        assertEquals("14", parts.day)
        assertEquals("03", parts.month)
        assertEquals("2026", parts.year)
    }

    @Test fun queryPartsDmyNoLeadingZerosSingleDigit() {
        // March 3 → day = "3", month = "3"
        val parts = DateFormatOption.DMY_NO_LEADING_ZEROS.queryParts("332026", dayDigits = 1)
        assertEquals("3", parts.day)
        assertEquals("3", parts.month)
        assertEquals("2026", parts.year)
    }

    @Test fun allCasesPresent() {
        assertEquals(5, DateFormatOption.entries.size)
    }
}
```

- [ ] **Step 2: Run test — expect compile failure**

In Android Studio: right-click `DateFormatOptionTest` → Run. Expected: compile error (class doesn't exist yet).

- [ ] **Step 3: Create DateFormatOption.kt**

```kotlin
// core/domain/DateFormatOption.kt
package academy.glasscode.piday.core.domain

// WHY: Mirrors iOS DateFormatOption exactly. Kotlin enum classes are sealed by default,
// so all cases are listed here. `serialName` matches the raw value used in the JSON index.
enum class DateFormatOption(val serialName: String) {
    YYYYMMDD("yyyymmdd"),
    DDMMYYYY("ddmmyyyy"),
    MMDDYYYY("mmddyyyy"),
    YYMMDD("yymmdd"),
    DMY_NO_LEADING_ZEROS("dmyNoLeadingZeros");

    val displayName: String get() = when (this) {
        YYYYMMDD -> "YYYYMMDD"
        DDMMYYYY -> "DDMMYYYY"
        MMDDYYYY -> "MMDDYYYY"
        YYMMDD   -> "YYMMDD"
        DMY_NO_LEADING_ZEROS -> "D/M/YYYY"
    }

    val description: String get() = when (this) {
        YYYYMMDD -> "Canonical ISO-style calendar order."
        DDMMYYYY -> "Day-first format common outside the US."
        MMDDYYYY -> "Month-first format common in the US."
        YYMMDD   -> "Compact six-digit version."
        DMY_NO_LEADING_ZEROS -> "Digits only, no leading zeros."
    }

    data class QueryParts(val day: String, val month: String, val year: String)

    // WHY dayDigits param: for D/M/YYYY, a single-digit day means the split point differs.
    // Pass Calendar.get(Calendar.DAY_OF_MONTH) < 10 ? 1 : 2 when you have the date.
    fun queryParts(query: String, dayDigits: Int = 2): QueryParts = when (this) {
        YYYYMMDD -> if (query.length >= 8) QueryParts(
            day   = query.substring(6, 8),
            month = query.substring(4, 6),
            year  = query.substring(0, 4)
        ) else QueryParts("", "", query)

        DDMMYYYY -> if (query.length >= 8) QueryParts(
            day   = query.substring(0, 2),
            month = query.substring(2, 4),
            year  = query.substring(4)
        ) else QueryParts(query, "", "")

        MMDDYYYY -> if (query.length >= 8) QueryParts(
            day   = query.substring(2, 4),
            month = query.substring(0, 2),
            year  = query.substring(4)
        ) else QueryParts(query, "", "")

        YYMMDD -> if (query.length >= 6) QueryParts(
            day   = query.substring(4, 6),
            month = query.substring(2, 4),
            year  = query.substring(0, 2)
        ) else QueryParts("", "", query)

        DMY_NO_LEADING_ZEROS -> {
            if (query.length < 5) return QueryParts(query, "", "")
            val yearPart = query.takeLast(4)
            val dayMonth = query.dropLast(4)
            val clampedLen = dayDigits.coerceIn(1, (dayMonth.length - 1).coerceAtLeast(1))
            QueryParts(
                day   = dayMonth.take(clampedLen),
                month = dayMonth.drop(clampedLen),
                year  = yearPart
            )
        }
    }

    companion object {
        fun fromSerialName(name: String): DateFormatOption? =
            entries.firstOrNull { it.serialName == name }
    }
}
```

- [ ] **Step 4: Create IndexingConvention.kt**

```kotlin
// core/domain/IndexingConvention.kt
package academy.glasscode.piday.core.domain

enum class IndexingConvention {
    ONE_BASED, ZERO_BASED;

    val label: String get() = when (this) {
        ONE_BASED  -> "1-based"
        ZERO_BASED -> "0-based"
    }

    val explainer: String get() = when (this) {
        ONE_BASED  -> "Digit 1 is the first digit after the decimal point."
        ZERO_BASED -> "Digit 0 is the first digit after the decimal point."
    }

    fun displayPosition(storedPosition: Int): Int = when (this) {
        ONE_BASED  -> storedPosition
        ZERO_BASED -> storedPosition - 1
    }
}
```

- [ ] **Step 5: Create SearchFormatPreference.kt**

```kotlin
// core/domain/SearchFormatPreference.kt
package academy.glasscode.piday.core.domain

enum class SearchFormatPreference {
    INTERNATIONAL, AMERICAN, ISO8601, ALL;

    val label: String get() = when (this) {
        INTERNATIONAL -> "DD/MM"
        AMERICAN      -> "MM/DD"
        ISO8601       -> "ISO"
        ALL           -> "All"
    }

    val title: String get() = when (this) {
        INTERNATIONAL -> "International"
        AMERICAN      -> "American"
        ISO8601       -> "ISO 8601"
        ALL           -> "Indexed Formats"
    }

    val formats: List<DateFormatOption> get() = when (this) {
        INTERNATIONAL -> listOf(DateFormatOption.DDMMYYYY, DateFormatOption.DMY_NO_LEADING_ZEROS)
        AMERICAN      -> listOf(DateFormatOption.MMDDYYYY)
        ISO8601       -> listOf(DateFormatOption.YYYYMMDD)
        ALL           -> listOf(DateFormatOption.DDMMYYYY, DateFormatOption.DMY_NO_LEADING_ZEROS,
                                DateFormatOption.MMDDYYYY, DateFormatOption.YYYYMMDD, DateFormatOption.YYMMDD)
    }

    val heroFormat: DateFormatOption get() = when (this) {
        INTERNATIONAL, ALL -> DateFormatOption.DDMMYYYY
        AMERICAN           -> DateFormatOption.MMDDYYYY
        ISO8601            -> DateFormatOption.YYYYMMDD
    }

    val summary: String get() = when (this) {
        INTERNATIONAL -> "DDMMYYYY or D/M/YYYY"
        AMERICAN      -> "MMDDYYYY"
        ISO8601       -> "YYYYMMDD"
        ALL           -> "any indexed format"
    }
}
```

- [ ] **Step 6: Create PiMatch.kt**

```kotlin
// core/domain/PiMatch.kt
package academy.glasscode.piday.core.domain

// Mirrors iOS PiMatchResult, BestPiMatch, LookupSource, DateLookupSummary exactly.

data class PiMatchResult(
    val query: String,
    val format: DateFormatOption,
    val found: Boolean,
    val storedPosition: Int?,
    val excerpt: String?
) {
    companion object {
        // WHY: Matches with a position sort before those without; ties sort by format name.
        val byPosition: Comparator<PiMatchResult> = Comparator { l, r ->
            when {
                l.storedPosition != null && r.storedPosition != null -> l.storedPosition - r.storedPosition
                l.storedPosition != null -> -1
                r.storedPosition != null ->  1
                else -> l.format.displayName.compareTo(r.format.displayName)
            }
        }
    }
}

data class BestPiMatch(
    val format: DateFormatOption,
    val query: String,
    val storedPosition: Int,
    val excerpt: String
) {
    companion object {
        // WHY: Prefer padded formats over D/M/YYYY — shorter strings match more often by chance.
        val preferringPadded: Comparator<BestPiMatch> = Comparator { l, r ->
            val lPadded = l.format != DateFormatOption.DMY_NO_LEADING_ZEROS
            val rPadded = r.format != DateFormatOption.DMY_NO_LEADING_ZEROS
            when {
                lPadded != rPadded -> if (lPadded) -1 else 1
                else               -> l.storedPosition - r.storedPosition
            }
        }
    }
}

enum class LookupSource { BUNDLED, LIVE }

data class DateLookupSummary(
    val isoDate: String,
    val matches: List<PiMatchResult>,
    val bestMatch: BestPiMatch?,
    val source: LookupSource,
    val errorMessage: String?
) {
    val foundCount: Int get() = matches.count { it.found }
}
```

- [ ] **Step 7: Create CalendarModels.kt**

```kotlin
// core/domain/CalendarModels.kt
package academy.glasscode.piday.core.domain

import java.time.LocalDate

data class CalendarDay(
    val date: LocalDate,
    val dayNumber: Int,
    val isInDisplayedMonth: Boolean
)

data class MonthSection(
    val monthTitle: String,
    val weekdaySymbols: List<String>,
    val days: List<CalendarDay>
)

// WHY: DaySummary is the ViewModel-level type for one calendar cell.
// It combines CalendarDay with pi-hit metadata so the Composable is pure display logic.
data class DaySummary(
    val date: LocalDate,
    val dayNumber: Int,
    val isoDate: String,
    val isSelected: Boolean,
    val isInBundledRange: Boolean,
    val bestStoredPosition: Int?,
    val foundFormats: Int
) {
    val isFound: Boolean get() = bestStoredPosition != null

    fun displayedBestPosition(convention: IndexingConvention): Int? =
        bestStoredPosition?.let { convention.displayPosition(it) }

    val heatLevel: PiHeatLevel get() = when (bestStoredPosition) {
        null                 -> PiHeatLevel.NONE
        in 0 until 1_000    -> PiHeatLevel.HOT
        in 0 until 100_000  -> PiHeatLevel.WARM
        in 0 until 10_000_000 -> PiHeatLevel.COOL
        else                 -> PiHeatLevel.FAINT
    }
}

enum class PiHeatLevel { NONE, FAINT, COOL, WARM, HOT }
```

- [ ] **Step 8: Create SavedDate.kt**

```kotlin
// core/domain/SavedDate.kt
package academy.glasscode.piday.core.domain

import kotlinx.serialization.Serializable
import java.time.LocalDate
import java.util.UUID

// WHY: @Serializable from kotlinx.serialization replaces Swift's Codable.
// We store year/month/day as ints rather than serializing LocalDate directly,
// matching the iOS encoding exactly (so cloud/backup sync stays compatible).
@Serializable
data class SavedDate(
    val id: String = UUID.randomUUID().toString(),
    var label: String,
    val year: Int,
    val month: Int,
    val day: Int
) {
    val date: LocalDate get() = LocalDate.of(year, month, day)
    val isoDate: String get() = "%04d-%02d-%02d".format(year, month, day)

    fun matches(other: LocalDate): Boolean =
        other.year == year && other.monthValue == month && other.dayOfMonth == day

    companion object {
        fun from(date: LocalDate, label: String): SavedDate = SavedDate(
            label = label,
            year  = date.year,
            month = date.monthValue,
            day   = date.dayOfMonth
        )
    }
}
```

- [ ] **Step 9: Run tests — expect pass**

Run `DateFormatOptionTest` in Android Studio. Expected: all 5 tests pass.

- [ ] **Step 10: Commit**

```bash
git add app/src/main/java/academy/glasscode/piday/core/domain/
git add app/src/test/java/academy/glasscode/piday/DateFormatOptionTest.kt
git commit -m "feat(android): domain models — DateFormatOption, PiMatch, CalendarModels, SavedDate"
```

---

### Task 3: DateStringGenerator

**Files:**
- Create: `app/src/main/java/academy/glasscode/piday/core/data/DateStringGenerator.kt`
- Test: `app/src/test/java/academy/glasscode/piday/DateStringGeneratorTest.kt`

- [ ] **Step 1: Write the failing test**

```kotlin
// app/src/test/java/academy/glasscode/piday/DateStringGeneratorTest.kt
package academy.glasscode.piday

import academy.glasscode.piday.core.data.DateStringGenerator
import academy.glasscode.piday.core.domain.DateFormatOption
import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate

class DateStringGeneratorTest {
    private val gen = DateStringGenerator()
    private val piDay = LocalDate.of(2026, 3, 14) // Pi Day 2026

    @Test fun yyyymmdd() {
        val result = gen.strings(piDay, listOf(DateFormatOption.YYYYMMDD))
        assertEquals(listOf(DateFormatOption.YYYYMMDD to "20260314"), result)
    }

    @Test fun ddmmyyyy() {
        val result = gen.strings(piDay, listOf(DateFormatOption.DDMMYYYY))
        assertEquals(listOf(DateFormatOption.DDMMYYYY to "14032026"), result)
    }

    @Test fun mmddyyyy() {
        val result = gen.strings(piDay, listOf(DateFormatOption.MMDDYYYY))
        assertEquals(listOf(DateFormatOption.MMDDYYYY to "03142026"), result)
    }

    @Test fun yymmdd() {
        val result = gen.strings(piDay, listOf(DateFormatOption.YYMMDD))
        assertEquals(listOf(DateFormatOption.YYMMDD to "260314"), result)
    }

    @Test fun dmyNoLeadingZeros() {
        val result = gen.strings(piDay, listOf(DateFormatOption.DMY_NO_LEADING_ZEROS))
        assertEquals(listOf(DateFormatOption.DMY_NO_LEADING_ZEROS to "1432026"), result)
    }

    @Test fun isoDateString() {
        assertEquals("2026-03-14", gen.isoDateString(piDay))
    }

    @Test fun allFormats() {
        val result = gen.strings(piDay, DateFormatOption.entries)
        assertEquals(5, result.size)
    }
}
```

- [ ] **Step 2: Run test — expect compile failure**

- [ ] **Step 3: Create DateStringGenerator.kt**

```kotlin
// core/data/DateStringGenerator.kt
package academy.glasscode.piday.core.data

import academy.glasscode.piday.core.domain.DateFormatOption
import java.time.LocalDate

// WHY: Pure function — Date → list of (format, queryString) pairs.
// No Android dependencies, fully unit-testable on the JVM.
class DateStringGenerator {

    fun strings(date: LocalDate, formats: List<DateFormatOption>): List<Pair<DateFormatOption, String>> {
        val yyyy = "%04d".format(date.year)
        val yy   = "%02d".format(date.year % 100)
        val mm   = "%02d".format(date.monthValue)
        val dd   = "%02d".format(date.dayOfMonth)
        val d    = date.dayOfMonth.toString()
        val m    = date.monthValue.toString()

        return formats.map { format ->
            format to when (format) {
                DateFormatOption.YYYYMMDD           -> "$yyyy$mm$dd"
                DateFormatOption.DDMMYYYY           -> "$dd$mm$yyyy"
                DateFormatOption.MMDDYYYY           -> "$mm$dd$yyyy"
                DateFormatOption.YYMMDD             -> "$yy$mm$dd"
                DateFormatOption.DMY_NO_LEADING_ZEROS -> "$d$m${date.year}"
            }
        }
    }

    // Canonical ISO key used in the bundled index and lookup caches.
    fun isoDateString(date: LocalDate): String = "%04d-%02d-%02d".format(
        date.year, date.monthValue, date.dayOfMonth
    )
}
```

- [ ] **Step 4: Run tests — expect all pass**

- [ ] **Step 5: Commit**

```bash
git add app/src/main/java/academy/glasscode/piday/core/data/DateStringGenerator.kt
git add app/src/test/java/academy/glasscode/piday/DateStringGeneratorTest.kt
git commit -m "feat(android): DateStringGenerator with full unit test coverage"
```

---

### Task 4: PiIndexPayload (JSON DTOs)

**Files:**
- Create: `app/src/main/java/academy/glasscode/piday/core/data/PiIndexPayload.kt`

No dedicated test here — PiStore tests (Task 5) will exercise deserialization end-to-end.

- [ ] **Step 1: Create PiIndexPayload.kt**

```kotlin
// core/data/PiIndexPayload.kt
package academy.glasscode.piday.core.data

import academy.glasscode.piday.core.domain.DateFormatOption
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonTransformingSerializer
import kotlinx.serialization.json.jsonObject

// WHY: These are DTOs — their only job is decoding the bundled JSON.
// The JSON uses camelCase string keys like "yyyymmdd"; we map them to DateFormatOption
// using a custom serializer so the domain layer stays clean.

@Serializable
data class PiFormatMatch(
    val query: String,
    val position: Int,
    val excerpt: String
)

// WHY a custom serializer: the JSON object under "formats" has keys like "yyyymmdd",
// "ddmmyyyy" etc. (the serialName of DateFormatOption). kotlinx.serialization cannot
// automatically use a custom key for Map<DateFormatOption, …> without this bridge.
@Serializable
data class PiDateRecord(
    val date: String,
    val formats: Map<String, PiFormatMatch>
) {
    // Convenience accessor that converts string keys to DateFormatOption
    fun formatMap(): Map<DateFormatOption, PiFormatMatch> =
        formats.mapNotNull { (key, value) ->
            DateFormatOption.fromSerialName(key)?.let { it to value }
        }.toMap()
}

@Serializable
data class PiIndexMetadata(
    val startYear: Int,
    val endYear: Int,
    val indexing: String,
    val excerptRadius: Int,
    val generatedAt: String,
    val source: String
)

@Serializable
data class PiIndexPayload(
    val metadata: PiIndexMetadata,
    val dates: Map<String, PiDateRecord>  // keyed by "YYYY-MM-DD"
)
```

- [ ] **Step 2: Commit**

```bash
git add app/src/main/java/academy/glasscode/piday/core/data/PiIndexPayload.kt
git commit -m "feat(android): PiIndexPayload JSON DTOs with kotlinx.serialization"
```

---

### Task 5: PiStore

**Files:**
- Create: `app/src/main/java/academy/glasscode/piday/core/repository/PiStore.kt`
- Test: `app/src/test/java/academy/glasscode/piday/PiStoreTest.kt`

- [ ] **Step 1: Write the failing test**

```kotlin
// app/src/test/java/academy/glasscode/piday/PiStoreTest.kt
package academy.glasscode.piday

import academy.glasscode.piday.core.data.PiIndexMetadata
import academy.glasscode.piday.core.data.PiIndexPayload
import academy.glasscode.piday.core.data.PiFormatMatch
import academy.glasscode.piday.core.data.PiDateRecord
import academy.glasscode.piday.core.domain.DateFormatOption
import academy.glasscode.piday.core.domain.LookupSource
import academy.glasscode.piday.core.repository.PiStore
import org.junit.Assert.*
import org.junit.Test
import java.time.LocalDate

class PiStoreTest {

    // Build a minimal in-memory payload so we don't need the real 12MB file.
    private fun makeStore(): PiStore {
        val payload = PiIndexPayload(
            metadata = PiIndexMetadata(
                startYear = 2026, endYear = 2035,
                indexing = "1-based", excerptRadius = 10,
                generatedAt = "2026-01-01", source = "test"
            ),
            dates = mapOf(
                "2026-03-14" to PiDateRecord(
                    date = "2026-03-14",
                    formats = mapOf(
                        "ddmmyyyy" to PiFormatMatch(query = "14032026", position = 4243, excerpt = "...14032026...")
                    )
                )
            )
        )
        return PiStore(payload)
    }

    @Test fun lookupFoundDate() {
        val store = makeStore()
        val summary = store.summary(
            LocalDate.of(2026, 3, 14),
            listOf(DateFormatOption.DDMMYYYY)
        )
        assertNotNull(summary.bestMatch)
        assertEquals(4243, summary.bestMatch!!.storedPosition)
        assertEquals(LookupSource.BUNDLED, summary.source)
    }

    @Test fun lookupNotFoundDate() {
        val store = makeStore()
        // Jan 1, 2026 is not in our test payload
        val summary = store.summary(
            LocalDate.of(2026, 1, 1),
            listOf(DateFormatOption.DDMMYYYY)
        )
        assertNull(summary.bestMatch)
        assertEquals(0, summary.foundCount)
    }

    @Test fun indexedYearRange() {
        val store = makeStore()
        assertTrue(store.isInIndexedRange(LocalDate.of(2026, 1, 1)))
        assertTrue(store.isInIndexedRange(LocalDate.of(2035, 12, 31)))
        assertFalse(store.isInIndexedRange(LocalDate.of(2024, 6, 15)))
    }
}
```

- [ ] **Step 2: Run test — expect compile failure**

- [ ] **Step 3: Create PiStore.kt**

```kotlin
// core/repository/PiStore.kt
package academy.glasscode.piday.core.repository

import academy.glasscode.piday.core.data.DateStringGenerator
import academy.glasscode.piday.core.data.PiIndexPayload
import academy.glasscode.piday.core.domain.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import java.io.InputStream
import java.time.LocalDate

class PiStore(payload: PiIndexPayload? = null) {
    // WHY @Volatile: payload is written once (on a background thread during load)
    // then only read. @Volatile ensures the write is visible to all threads immediately.
    @Volatile private var payload: PiIndexPayload? = payload
    private val generator = DateStringGenerator()

    // WHY lenient JSON: the real index file may have unknown keys added in future.
    private val json = Json { ignoreUnknownKeys = true }

    suspend fun loadFromStream(stream: InputStream) {
        // WHY Dispatchers.IO: reading 12MB from disk is blocking I/O.
        // Running it on the IO dispatcher frees the main thread during load.
        val loaded = withContext(Dispatchers.IO) {
            stream.use { json.decodeFromString<PiIndexPayload>(it.readBytes().decodeToString()) }
        }
        payload = loaded
    }

    val indexedYearRange: IntRange? get() {
        val meta = payload?.metadata ?: return null
        return meta.startYear..meta.endYear
    }

    val excerptRadius: Int get() = payload?.metadata?.excerptRadius ?: 20

    fun isInIndexedRange(date: LocalDate): Boolean {
        val range = indexedYearRange ?: return false
        return date.year in range
    }

    fun summary(date: LocalDate, formats: List<DateFormatOption>): DateLookupSummary {
        val isoDate = generator.isoDateString(date)
        val queries = generator.strings(date, formats)
        val record = payload?.dates?.get(isoDate)
        val formatMap = record?.formatMap() ?: emptyMap()

        val matches = queries.map { (format, query) ->
            val hit = formatMap[format]
            if (hit != null && hit.query == query) {
                PiMatchResult(query, format, found = true, storedPosition = hit.position, excerpt = hit.excerpt)
            } else {
                PiMatchResult(query, format, found = false, storedPosition = null, excerpt = null)
            }
        }.sortedWith(PiMatchResult.byPosition)

        val bestMatch = matches
            .mapNotNull { r ->
                if (r.storedPosition != null && r.excerpt != null)
                    BestPiMatch(r.format, r.query, r.storedPosition, r.excerpt)
                else null
            }
            .minWithOrNull(BestPiMatch.preferringPadded)

        return DateLookupSummary(
            isoDate      = isoDate,
            matches      = matches,
            bestMatch    = bestMatch,
            source       = LookupSource.BUNDLED,
            errorMessage = null
        )
    }
}
```

- [ ] **Step 4: Run tests — expect all pass**

- [ ] **Step 5: Commit**

```bash
git add app/src/main/java/academy/glasscode/piday/core/repository/PiStore.kt
git add app/src/test/java/academy/glasscode/piday/PiStoreTest.kt
git commit -m "feat(android): PiStore — load bundled JSON index and O(1) date lookup"
```

---

### Task 6: PiLiveLookupService

**Files:**
- Create: `app/src/main/java/academy/glasscode/piday/core/repository/PiLiveLookupService.kt`

No unit test here — the live API requires network. Integration-test manually in a later task.

- [ ] **Step 1: Create PiLiveLookupService.kt**

```kotlin
// core/repository/PiLiveLookupService.kt
package academy.glasscode.piday.core.repository

import academy.glasscode.piday.core.data.DateStringGenerator
import academy.glasscode.piday.core.domain.*
import io.ktor.client.*
import io.ktor.client.call.*
import io.ktor.client.engine.android.*
import io.ktor.client.plugins.contentnegotiation.*
import io.ktor.client.request.*
import io.ktor.serialization.kotlinx.json.*
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.time.LocalDate

class PiLiveLookupService(
    private val excerptRadius: Int = 496
) {
    @Serializable private data class LookupResponse(
        val resultStringIdx: Int,
        val numResults: Int
    )

    @Serializable private data class DigitsResponse(val content: String)

    private val generator = DateStringGenerator()

    // WHY a single shared client: Ktor clients hold a thread pool. Creating one per
    // request would leak resources. This client is safe to use concurrently.
    private val client = HttpClient(Android) {
        install(ContentNegotiation) {
            json(Json { ignoreUnknownKeys = true })
        }
        engine {
            connectTimeout = 12_000
            socketTimeout  = 30_000
        }
    }

    suspend fun summary(date: LocalDate, formats: List<DateFormatOption>): DateLookupSummary {
        val isoDate = generator.isoDateString(date)
        val queries = generator.strings(date, formats)

        // WHY coroutineScope + async/awaitAll: parallel fan-out of all format lookups,
        // equivalent to Swift's withThrowingTaskGroup. Cuts latency from O(n*RTT) to O(RTT).
        val matches: List<PiMatchResult> = coroutineScope {
            queries.map { (format, query) ->
                async {
                    runCatching { lookup(query, format) }
                        .getOrElse {
                            PiMatchResult(query, format, found = false, storedPosition = null, excerpt = null)
                        }
                        ?: PiMatchResult(query, format, found = false, storedPosition = null, excerpt = null)
                }
            }.awaitAll()
        }.sortedWith(PiMatchResult.byPosition)

        val bestMatch = matches.mapNotNull { r ->
            if (r.storedPosition != null && r.excerpt != null)
                BestPiMatch(r.format, r.query, r.storedPosition, r.excerpt)
            else null
        }.minWithOrNull(BestPiMatch.preferringPadded)

        return DateLookupSummary(
            isoDate = isoDate,
            matches = matches,
            bestMatch = bestMatch,
            source = LookupSource.LIVE,
            errorMessage = null
        )
    }

    // Arbitrary digit-sequence search (for FreeSearchViewModel).
    suspend fun searchDigits(digits: String): Pair<Int, String>? {
        val result = lookup(digits, DateFormatOption.DDMMYYYY) ?: return null
        val position = result.storedPosition ?: return null
        val excerpt = result.excerpt ?: return null
        return position to excerpt
    }

    private suspend fun lookup(query: String, format: DateFormatOption): PiMatchResult? {
        val response: LookupResponse = client.get(
            "https://v2.api.pisearch.joshkeegan.co.uk/api/v1/Lookup"
        ) {
            parameter("namedDigits", "pi")
            parameter("find", query)
            parameter("resultId", "0")
        }.body()

        if (response.numResults == 0) return null
        val storedPosition = response.resultStringIdx + 1
        val excerpt = fetchExcerpt(storedPosition, query)

        return PiMatchResult(query, format, found = true, storedPosition = storedPosition, excerpt = excerpt)
    }

    private suspend fun fetchExcerpt(position: Int, query: String): String {
        val start = maxOf(1, position - excerptRadius)
        val response: DigitsResponse = client.get("https://api.pi.delivery/v1/pi") {
            parameter("start", start)
            parameter("numberOfDigits", query.length + excerptRadius * 2)
        }.body()

        val offset = minOf(excerptRadius, position - 1)
        val content = response.content
        require(offset < content.length && content.substring(offset).startsWith(query)) {
            "Live pi lookup returned digits that did not match the requested date."
        }
        return content
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add app/src/main/java/academy/glasscode/piday/core/repository/PiLiveLookupService.kt
git commit -m "feat(android): PiLiveLookupService — parallel format fan-out via Ktor"
```

---

### Task 7: PiRepository interface + DefaultPiRepository

**Files:**
- Create: `app/src/main/java/academy/glasscode/piday/core/repository/PiRepository.kt`
- Create: `app/src/main/java/academy/glasscode/piday/core/repository/DefaultPiRepository.kt`

- [ ] **Step 1: Create PiRepository.kt**

```kotlin
// core/repository/PiRepository.kt
package academy.glasscode.piday.core.repository

import academy.glasscode.piday.core.domain.DateFormatOption
import academy.glasscode.piday.core.domain.DateLookupSummary
import java.io.InputStream
import java.time.LocalDate

// WHY an interface: AppViewModel depends on this, not on the concrete impl.
// Tests inject a FakePiRepository; production injects DefaultPiRepository.
interface PiRepository {
    suspend fun loadBundledIndex(stream: InputStream)
    suspend fun summary(date: LocalDate, formats: List<DateFormatOption>): DateLookupSummary
    fun bundledSummary(date: LocalDate, formats: List<DateFormatOption>): DateLookupSummary
    fun isInBundledRange(date: LocalDate): Boolean
    fun clearCache()
    val indexedYearRange: IntRange?
    val excerptRadius: Int
}
```

- [ ] **Step 2: Create DefaultPiRepository.kt**

```kotlin
// core/repository/DefaultPiRepository.kt
package academy.glasscode.piday.core.repository

import academy.glasscode.piday.core.data.DateStringGenerator
import academy.glasscode.piday.core.domain.*
import java.io.InputStream
import java.time.LocalDate

// WHY: DefaultPiRepository owns the routing decision: bundled index vs live API.
// AppViewModel asks "give me a summary" — it never knows which source answered.
class DefaultPiRepository : PiRepository {
    private val store = PiStore()
    private val liveLookup = PiLiveLookupService()
    private val generator = DateStringGenerator()
    private val cache = mutableMapOf<String, Pair<DateLookupSummary, Long?>>()
    private val errorCacheTtlMs = 60_000L

    override val indexedYearRange: IntRange? get() = store.indexedYearRange
    override val excerptRadius: Int get() = store.excerptRadius

    override suspend fun loadBundledIndex(stream: InputStream) {
        store.loadFromStream(stream)
        cache.clear()
    }

    override suspend fun summary(date: LocalDate, formats: List<DateFormatOption>): DateLookupSummary {
        val key = cacheKey(date, formats)
        cache[key]?.let { (result, cachedAt) ->
            if (result.errorMessage != null && cachedAt != null) {
                if (System.currentTimeMillis() - cachedAt < errorCacheTtlMs) return result
                else cache.remove(key)
            } else {
                return result
            }
        }

        val result = if (store.isInIndexedRange(date)) {
            store.summary(date, formats)
        } else {
            runCatching { liveLookup.summary(date, formats) }.getOrElse { error ->
                val isoDate = generator.isoDateString(date)
                val queries = generator.strings(date, formats)
                DateLookupSummary(
                    isoDate      = isoDate,
                    matches      = queries.map { (fmt, q) -> PiMatchResult(q, fmt, false, null, null) },
                    bestMatch    = null,
                    source       = LookupSource.LIVE,
                    errorMessage = error.message
                )
            }
        }

        cache[key] = result to (if (result.errorMessage != null) System.currentTimeMillis() else null)
        return result
    }

    override fun bundledSummary(date: LocalDate, formats: List<DateFormatOption>): DateLookupSummary {
        val key = cacheKey(date, formats)
        cache[key]?.let { (result, _) -> if (result.source == LookupSource.BUNDLED) return result }
        val result = store.summary(date, formats)
        cache[key] = result to null
        return result
    }

    override fun isInBundledRange(date: LocalDate) = store.isInIndexedRange(date)

    override fun clearCache() = cache.clear()

    private fun cacheKey(date: LocalDate, formats: List<DateFormatOption>): String {
        val iso = generator.isoDateString(date)
        val fmtKey = formats.map { it.serialName }.sorted().joinToString(",")
        return "$iso-$fmtKey"
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add app/src/main/java/academy/glasscode/piday/core/repository/
git commit -m "feat(android): PiRepository interface + DefaultPiRepository with cache"
```

---

## Phase 2: ViewModel + Core UI

### Task 8: AppViewModel

**Files:**
- Create: `app/src/main/java/academy/glasscode/piday/features/main/AppViewModel.kt`

- [ ] **Step 1: Create AppViewModel.kt**

```kotlin
// features/main/AppViewModel.kt
package academy.glasscode.piday.features.main

import academy.glasscode.piday.core.domain.*
import academy.glasscode.piday.core.repository.DefaultPiRepository
import academy.glasscode.piday.core.repository.PiRepository
import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.LocalDate
import java.time.YearMonth

// WHY AndroidViewModel: we need Application context to open the raw resource stream.
// This is the Kotlin/Android equivalent of @MainActor @Observable class AppViewModel.
class AppViewModel(
    app: Application,
    private val repository: PiRepository = DefaultPiRepository()
) : AndroidViewModel(app) {

    // --- Observable state (equivalent of iOS @Observable properties) ---
    private val _selectedDate = MutableStateFlow(LocalDate.now())
    val selectedDate: StateFlow<LocalDate> = _selectedDate.asStateFlow()

    private val _displayedMonth = MutableStateFlow(YearMonth.now())
    val displayedMonth: StateFlow<YearMonth> = _displayedMonth.asStateFlow()

    private val _lookupSummary = MutableStateFlow<DateLookupSummary?>(null)
    val lookupSummary: StateFlow<DateLookupSummary?> = _lookupSummary.asStateFlow()

    private val _isLoading = MutableStateFlow(true)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _daySummaries = MutableStateFlow<List<DaySummary>>(emptyList())
    val daySummaries: StateFlow<List<DaySummary>> = _daySummaries.asStateFlow()

    var searchPreference: SearchFormatPreference = SearchFormatPreference.INTERNATIONAL
        private set
    var indexingConvention: IndexingConvention = IndexingConvention.ONE_BASED
        private set

    val today: LocalDate = LocalDate.now()

    // Cancels any in-flight lookup so stale results can't clobber the current selection.
    private var lookupJob: Job? = null

    // Bounded month cache: max 6 entries (LRU)
    private val monthSummaryCache = LinkedHashMap<YearMonth, List<DaySummary>>(8, 0.75f, true)
    private val maxCacheSize = 6

    init {
        viewModelScope.launch { load() }
    }

    private suspend fun load() {
        _isLoading.value = true
        try {
            val stream = getApplication<Application>()
                .resources.openRawResource(
                    getApplication<Application>().resources.getIdentifier(
                        "pi_2026_2035_index", "raw",
                        getApplication<Application>().packageName
                    )
                )
            repository.loadBundledIndex(stream)
        } catch (e: Exception) {
            // Index load failed — live lookups will still work for individual dates
        }
        _isLoading.value = false
        refreshLookup()
        refreshDaySummaries()
    }

    fun selectDate(date: LocalDate) {
        _selectedDate.value = date
        _displayedMonth.value = YearMonth.of(date.year, date.month)
        scheduleRefresh()
    }

    fun nextDay() = selectDate(_selectedDate.value.plusDays(1))
    fun previousDay() = selectDate(_selectedDate.value.minusDays(1))

    fun setDisplayedMonth(month: YearMonth) {
        _displayedMonth.value = month
        refreshDaySummaries()
    }

    fun setSearchPreference(pref: SearchFormatPreference) {
        searchPreference = pref
        repository.clearCache()
        monthSummaryCache.clear()
        scheduleRefresh()
        refreshDaySummaries()
    }

    fun setIndexingConvention(convention: IndexingConvention) {
        indexingConvention = convention
    }

    private fun scheduleRefresh() {
        lookupJob?.cancel()
        lookupJob = viewModelScope.launch {
            delay(50) // debounce rapid swipes
            refreshLookup()
        }
    }

    private suspend fun refreshLookup() {
        val date = _selectedDate.value
        val formats = searchPreference.formats
        _lookupSummary.value = repository.summary(date, formats)
    }

    private fun refreshDaySummaries() {
        viewModelScope.launch {
            val month = _displayedMonth.value
            // Check cache first
            monthSummaryCache[month]?.let { cached ->
                val selected = _selectedDate.value
                _daySummaries.value = cached.map { ds ->
                    ds.copy(isSelected = ds.date == selected)
                }
                return@launch
            }

            val summaries = withContext(Dispatchers.Default) {
                buildMonthSummaries(month)
            }
            storeSummaryCache(summaries, month)
            _daySummaries.value = summaries
        }
    }

    private fun buildMonthSummaries(month: YearMonth): List<DaySummary> {
        val formats = searchPreference.formats
        val selected = _selectedDate.value
        val firstDay = month.atDay(1)
        val lastDay = month.atEndOfMonth()

        // Build calendar grid: fill leading days from prior month
        val startDayOfWeek = firstDay.dayOfWeek.value % 7 // 0=Sun
        val days = mutableListOf<LocalDate>()
        for (i in startDayOfWeek downTo 1) days.add(firstDay.minusDays(i.toLong()))
        var d = firstDay
        while (!d.isAfter(lastDay)) { days.add(d); d = d.plusDays(1) }
        while (days.size % 7 != 0) days.add(days.last().plusDays(1))

        return days.map { date ->
            val inMonth = date.month == month.month
            val bundled = repository.bundledSummary(date, formats)
            DaySummary(
                date              = date,
                dayNumber         = date.dayOfMonth,
                isoDate           = "%04d-%02d-%02d".format(date.year, date.monthValue, date.dayOfMonth),
                isSelected        = date == selected,
                isInBundledRange  = repository.isInBundledRange(date),
                bestStoredPosition = bundled.bestMatch?.storedPosition,
                foundFormats      = bundled.foundCount
            )
        }
    }

    private fun storeSummaryCache(summaries: List<DaySummary>, month: YearMonth) {
        if (monthSummaryCache.size >= maxCacheSize) {
            monthSummaryCache.remove(monthSummaryCache.keys.first())
        }
        monthSummaryCache[month] = summaries
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add app/src/main/java/academy/glasscode/piday/features/main/AppViewModel.kt
git commit -m "feat(android): AppViewModel with StateFlow, month cache, debounced lookup"
```

---

### Task 9: Theme system

**Files:**
- Create: `app/src/main/java/academy/glasscode/piday/design/AppTheme.kt`
- Create: `app/src/main/java/academy/glasscode/piday/design/PiPalette.kt`

- [ ] **Step 1: Create AppTheme.kt**

```kotlin
// design/AppTheme.kt
package academy.glasscode.piday.design

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

// WHY: Mirrors iOS AppTheme enum. Each theme maps to a Material3 ColorScheme plus
// our own PiPalette for semantic tokens the canvas and heat map need.

enum class AppThemeOption {
    SLATE, FROST, COPPICE, EMBER, AURORA, CUSTOM
}

data class AppPalette(
    val background: Color,
    val surface: Color,
    val onBackground: Color,
    val accent: Color,
    val border: Color,
    val dayColor: Color,
    val monthColor: Color,
    val yearColor: Color,
    val heatNone: Color,
    val heatFaint: Color,
    val heatCool: Color,
    val heatWarm: Color,
    val heatHot: Color,
    val isDark: Boolean
)

object PiThemes {
    val slate = AppPalette(
        background    = Color(0xFF1C1C1E),
        surface       = Color(0xFF2C2C2E),
        onBackground  = Color(0xFFEEEEEE),
        accent        = Color(0xFF5E9CEA),
        border        = Color(0xFF3A3A3C),
        dayColor      = Color(0xFFFF9500),
        monthColor    = Color(0xFF32D74B),
        yearColor     = Color(0xFF5E9CEA),
        heatNone      = Color(0xFF2C2C2E),
        heatFaint     = Color(0xFF2A3A4A),
        heatCool      = Color(0xFF1E4A7A),
        heatWarm      = Color(0xFF2460A0),
        heatHot       = Color(0xFF4F8EDB),
        isDark        = true
    )
    val frost = AppPalette(
        background    = Color(0xFFF5F5F7),
        surface       = Color(0xFFFFFFFF),
        onBackground  = Color(0xFF1C1C1E),
        accent        = Color(0xFF007AFF),
        border        = Color(0xFFD1D1D6),
        dayColor      = Color(0xFFFF6B00),
        monthColor    = Color(0xFF00A550),
        yearColor     = Color(0xFF007AFF),
        heatNone      = Color(0xFFE5E5EA),
        heatFaint     = Color(0xFFD0E4F7),
        heatCool      = Color(0xFF90C4F0),
        heatWarm      = Color(0xFF4A9EE8),
        heatHot       = Color(0xFF007AFF),
        isDark        = false
    )
    // Add coppice, ember, aurora as needed — start with slate + frost
}

val LocalAppPalette = staticCompositionLocalOf { PiThemes.slate }

@Composable
fun PiDayTheme(
    palette: AppPalette = PiThemes.slate,
    content: @Composable () -> Unit
) {
    val colorScheme = if (palette.isDark) darkColorScheme(
        background = palette.background,
        surface    = palette.surface,
        primary    = palette.accent,
    ) else lightColorScheme(
        background = palette.background,
        surface    = palette.surface,
        primary    = palette.accent,
    )

    CompositionLocalProvider(LocalAppPalette provides palette) {
        MaterialTheme(colorScheme = colorScheme, content = content)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add app/src/main/java/academy/glasscode/piday/design/
git commit -m "feat(android): Material3 theme system with Slate + Frost palettes"
```

---

### Task 10: MainScreen skeleton + wiring

**Files:**
- Create: `app/src/main/java/academy/glasscode/piday/features/main/MainScreen.kt`
- Modify: `app/src/main/java/academy/glasscode/piday/MainActivity.kt`

- [ ] **Step 1: Create MainScreen.kt**

```kotlin
// features/main/MainScreen.kt
package academy.glasscode.piday.features.main

import academy.glasscode.piday.design.LocalAppPalette
import academy.glasscode.piday.design.PiDayTheme
import academy.glasscode.piday.design.PiThemes
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel

@Composable
fun MainScreen(vm: AppViewModel = viewModel()) {
    val palette = LocalAppPalette.current
    val selectedDate by vm.selectedDate.collectAsStateWithLifecycle()
    val lookupSummary by vm.lookupSummary.collectAsStateWithLifecycle()
    val isLoading by vm.isLoading.collectAsStateWithLifecycle()

    var showCalendar by remember { mutableStateOf(false) }
    var showDetail by remember { mutableStateOf(false) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.background)
            .systemBarsPadding()
    ) {
        // TODO Task 11: PiCanvasView goes here
        Text(
            text = "Pi Canvas — ${selectedDate}",
            color = palette.onBackground,
            modifier = Modifier.align(Alignment.Center)
        )

        // Bottom controls bar
        Row(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .padding(horizontal = 24.dp, vertical = 16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = { showCalendar = true }) {
                Icon(Icons.Default.CalendarMonth, "Calendar",
                     tint = palette.accent)
            }

            // Wordmark
            Text("π", style = MaterialTheme.typography.headlineLarge,
                 color = palette.accent)

            IconButton(onClick = { showDetail = true }) {
                Icon(Icons.Default.Info, "Detail",
                     tint = palette.accent)
            }
        }
    }

    // Sheets added in later tasks
}
```

- [ ] **Step 2: Update MainActivity.kt**

```kotlin
// MainActivity.kt
package academy.glasscode.piday

import academy.glasscode.piday.design.PiDayTheme
import academy.glasscode.piday.design.PiThemes
import academy.glasscode.piday.features.main.MainScreen
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            PiDayTheme(palette = PiThemes.slate) {
                MainScreen()
            }
        }
    }
}
```

- [ ] **Step 3: Run on emulator — expect dark screen with "Pi Canvas — [date]" centered + bottom icons**

- [ ] **Step 4: Commit**

```bash
git add app/src/main/java/academy/glasscode/piday/features/main/MainScreen.kt
git add app/src/main/java/academy/glasscode/piday/MainActivity.kt
git commit -m "feat(android): MainScreen skeleton — palette, bottom bar, sheet stubs"
```

---

### Task 11: PiCanvasView (digit canvas)

This is the most complex UI piece. The canvas draws Pi digits with the matched date sequence highlighted and color-coded (day=orange, month=teal, year=blue).

**Files:**
- Create: `app/src/main/java/academy/glasscode/piday/features/canvas/PiCanvasView.kt`

- [ ] **Step 1: Create PiCanvasView.kt**

```kotlin
// features/canvas/PiCanvasView.kt
package academy.glasscode.piday.features.canvas

import academy.glasscode.piday.core.domain.BestPiMatch
import academy.glasscode.piday.core.domain.DateFormatOption
import academy.glasscode.piday.design.AppPalette
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.*
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.sp
import kotlin.math.floor

@Composable
fun PiCanvasView(
    excerpt: String?,
    bestMatch: BestPiMatch?,
    palette: AppPalette,
    modifier: Modifier = Modifier,
    onSwipeLeft: () -> Unit = {},
    onSwipeRight: () -> Unit = {},
    onSwipeUp: () -> Unit = {}
) {
    val textMeasurer = rememberTextMeasurer()

    // Reveal animation: fade in the canvas content when excerpt changes
    val revealAlpha by animateFloatAsState(
        targetValue = if (excerpt != null) 1f else 0f,
        animationSpec = tween(400),
        label = "reveal"
    )

    // Swipe gesture tracking
    var dragStartX by remember { mutableFloatStateOf(0f) }
    var dragStartY by remember { mutableFloatStateOf(0f) }

    Canvas(
        modifier = modifier
            .pointerInput(Unit) {
                detectHorizontalDragGestures(
                    onDragStart = { offset ->
                        dragStartX = offset.x
                        dragStartY = offset.y
                    },
                    onDragEnd = {},
                    onHorizontalDrag = { change, dragAmount ->
                        val totalX = change.position.x - dragStartX
                        val totalY = change.position.y - dragStartY
                        if (kotlin.math.abs(totalX) > 50f && kotlin.math.abs(totalX) > kotlin.math.abs(totalY)) {
                            if (totalX > 0) onSwipeRight() else onSwipeLeft()
                            dragStartX = change.position.x
                        }
                    }
                )
            }
    ) {
        if (excerpt == null || bestMatch == null) {
            drawNothingFound(palette)
            return@Canvas
        }

        drawDigitCanvas(
            excerpt = excerpt,
            bestMatch = bestMatch,
            palette = palette,
            textMeasurer = textMeasurer,
            alpha = revealAlpha
        )
    }
}

private fun DrawScope.drawNothingFound(palette: AppPalette) {
    // Placeholder — "not found" state shows grey digits
    val text = "3.14159265358979323846264338327950288..."
    // In a real pass, draw dimmed placeholder digits here
}

private fun DrawScope.drawDigitCanvas(
    excerpt: String,
    bestMatch: BestPiMatch,
    palette: AppPalette,
    textMeasurer: TextMeasurer,
    alpha: Float
) {
    val fontSize = 18.sp
    val style = TextStyle(
        fontFamily = FontFamily.Monospace,
        fontSize = fontSize,
        color = palette.onBackground.copy(alpha = 0.4f * alpha)
    )

    // Calculate grid: how many chars fit per row
    val charWidth = textMeasurer.measure("0", style).size.width.toFloat()
    val charHeight = textMeasurer.measure("0", style).size.height.toFloat()
    val cols = floor(size.width / charWidth).toInt().coerceAtLeast(1)
    val rows = floor(size.height / charHeight).toInt().coerceAtLeast(1)

    // The bestMatch position within the excerpt — the excerpt center is the match
    val excerptRadius = excerpt.length / 2
    val matchStartInExcerpt = excerptRadius  // approximately centered

    // Determine the color-coded segments (day/month/year)
    val parts = bestMatch.format.queryParts(bestMatch.query,
        dayDigits = if (bestMatch.query.length <= 7) 1 else 2)
    val dayLen   = parts.day.length
    val monthLen = parts.month.length
    val yearLen  = parts.year.length
    val queryLen = dayLen + monthLen + yearLen

    // Compute color ranges relative to start of query within excerpt
    data class ColorRange(val start: Int, val end: Int, val color: Color)
    val colorRanges = when (bestMatch.format) {
        DateFormatOption.YYYYMMDD -> listOf(
            ColorRange(matchStartInExcerpt, matchStartInExcerpt + yearLen, palette.yearColor),
            ColorRange(matchStartInExcerpt + yearLen, matchStartInExcerpt + yearLen + monthLen, palette.monthColor),
            ColorRange(matchStartInExcerpt + yearLen + monthLen, matchStartInExcerpt + queryLen, palette.dayColor),
        )
        DateFormatOption.DDMMYYYY, DateFormatOption.DMY_NO_LEADING_ZEROS -> listOf(
            ColorRange(matchStartInExcerpt, matchStartInExcerpt + dayLen, palette.dayColor),
            ColorRange(matchStartInExcerpt + dayLen, matchStartInExcerpt + dayLen + monthLen, palette.monthColor),
            ColorRange(matchStartInExcerpt + dayLen + monthLen, matchStartInExcerpt + queryLen, palette.yearColor),
        )
        DateFormatOption.MMDDYYYY -> listOf(
            ColorRange(matchStartInExcerpt, matchStartInExcerpt + monthLen, palette.monthColor),
            ColorRange(matchStartInExcerpt + monthLen, matchStartInExcerpt + monthLen + dayLen, palette.dayColor),
            ColorRange(matchStartInExcerpt + monthLen + dayLen, matchStartInExcerpt + queryLen, palette.yearColor),
        )
        DateFormatOption.YYMMDD -> listOf(
            ColorRange(matchStartInExcerpt, matchStartInExcerpt + yearLen, palette.yearColor),
            ColorRange(matchStartInExcerpt + yearLen, matchStartInExcerpt + yearLen + monthLen, palette.monthColor),
            ColorRange(matchStartInExcerpt + yearLen + monthLen, matchStartInExcerpt + queryLen, palette.dayColor),
        )
    }

    // Render visible portion of excerpt on a character grid
    val totalVisible = cols * rows
    val excerptStart = (matchStartInExcerpt - (rows / 2) * cols).coerceAtLeast(0)
    val visibleExcerpt = excerpt.substring(excerptStart, minOf(excerptStart + totalVisible, excerpt.length))

    for (i in visibleExcerpt.indices) {
        val globalIdx = excerptStart + i
        val col = i % cols
        val row = i / cols
        val x = col * charWidth
        val y = row * charHeight

        val charColor = colorRanges.firstOrNull { globalIdx in it.start until it.end }?.color
            ?: palette.onBackground.copy(alpha = 0.35f)

        drawText(
            textMeasurer = textMeasurer,
            text = visibleExcerpt[i].toString(),
            style = style.copy(color = charColor.copy(alpha = charColor.alpha * alpha)),
            topLeft = Offset(x, y)
        )
    }
}

// Expose these as tokens on AppPalette additions (add to AppTheme.kt)
private val AppPalette.dayColor: Color get() = Color(0xFFFF9500)
private val AppPalette.monthColor: Color get() = Color(0xFF32D74B)
private val AppPalette.yearColor: Color get() = Color(0xFF5E9CEA)
```

- [ ] **Step 2: Wire PiCanvasView into MainScreen**

Replace the `Text("Pi Canvas…")` placeholder in `MainScreen.kt` with:

```kotlin
val lookupSummary by vm.lookupSummary.collectAsStateWithLifecycle()

PiCanvasView(
    excerpt   = lookupSummary?.bestMatch?.excerpt,
    bestMatch = lookupSummary?.bestMatch,
    palette   = palette,
    modifier  = Modifier.fillMaxSize(),
    onSwipeLeft  = { vm.nextDay() },
    onSwipeRight = { vm.previousDay() },
    onSwipeUp    = { showDetail = true }
)
```

- [ ] **Step 3: Run on emulator — expect Pi digits scrolling with colored date sequence**

- [ ] **Step 4: Commit**

```bash
git add app/src/main/java/academy/glasscode/piday/features/canvas/
git commit -m "feat(android): PiCanvasView — monospace digit grid with color-coded date sequence"
```

---

### Task 12: CalendarSheet (heat map)

**Files:**
- Create: `app/src/main/java/academy/glasscode/piday/features/calendar/CalendarSheet.kt`

- [ ] **Step 1: Create CalendarSheet.kt**

```kotlin
// features/calendar/CalendarSheet.kt
package academy.glasscode.piday.features.calendar

import academy.glasscode.piday.core.domain.*
import academy.glasscode.piday.design.AppPalette
import academy.glasscode.piday.features.main.AppViewModel
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.TextStyle
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CalendarSheet(
    vm: AppViewModel,
    palette: AppPalette,
    onDismiss: () -> Unit
) {
    val displayedMonth by vm.displayedMonth.collectAsStateWithLifecycle()
    val daySummaries by vm.daySummaries.collectAsStateWithLifecycle()
    val selectedDate by vm.selectedDate.collectAsStateWithLifecycle()
    val convention = vm.indexingConvention

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = palette.background
    ) {
        Column(modifier = Modifier.padding(horizontal = 16.dp)) {
            // Month navigation header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = { vm.setDisplayedMonth(displayedMonth.minusMonths(1)) }) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, "Previous month",
                         tint = palette.accent)
                }
                Text(
                    text = "${displayedMonth.month.getDisplayName(TextStyle.FULL, Locale.getDefault())} ${displayedMonth.year}",
                    color = palette.onBackground,
                    style = MaterialTheme.typography.titleMedium
                )
                IconButton(onClick = { vm.setDisplayedMonth(displayedMonth.plusMonths(1)) }) {
                    Icon(Icons.AutoMirrored.Filled.ArrowForward, "Next month",
                         tint = palette.accent)
                }
            }

            // Weekday headers
            val weekdays = listOf("S","M","T","W","T","F","S")
            Row(modifier = Modifier.fillMaxWidth()) {
                weekdays.forEach { day ->
                    Text(
                        text = day,
                        modifier = Modifier.weight(1f),
                        textAlign = TextAlign.Center,
                        color = palette.onBackground.copy(alpha = 0.5f),
                        fontSize = 12.sp
                    )
                }
            }

            Spacer(Modifier.height(4.dp))

            // Calendar grid
            LazyVerticalGrid(
                columns = GridCells.Fixed(7),
                modifier = Modifier.fillMaxWidth()
            ) {
                items(daySummaries) { summary ->
                    DayCell(
                        summary       = summary,
                        isToday       = summary.date == vm.today,
                        palette       = palette,
                        convention    = convention,
                        onClick       = {
                            vm.selectDate(summary.date)
                            onDismiss()
                        }
                    )
                }
            }

            Spacer(Modifier.height(32.dp))
        }
    }
}

@Composable
private fun DayCell(
    summary: DaySummary,
    isToday: Boolean,
    palette: AppPalette,
    convention: IndexingConvention,
    onClick: () -> Unit
) {
    val heatColor = when (summary.heatLevel) {
        PiHeatLevel.NONE  -> palette.heatNone
        PiHeatLevel.FAINT -> palette.heatFaint
        PiHeatLevel.COOL  -> palette.heatCool
        PiHeatLevel.WARM  -> palette.heatWarm
        PiHeatLevel.HOT   -> palette.heatHot
    }

    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .aspectRatio(1f)
            .padding(2.dp)
            .clip(CircleShape)
            .background(if (summary.isInBundledRange) heatColor else Color.Transparent)
            .clickable(enabled = summary.isInDisplayedMonth) { onClick() }
    ) {
        if (summary.isSelected) {
            Box(
                modifier = Modifier
                    .fillMaxSize(0.85f)
                    .clip(CircleShape)
                    .background(palette.accent)
            )
        } else if (isToday) {
            Box(
                modifier = Modifier
                    .fillMaxSize(0.85f)
                    .clip(CircleShape)
                    .background(Color.Transparent)
                    // TODO: draw accent ring border
            )
        }

        Text(
            text = if (summary.isInDisplayedMonth) summary.dayNumber.toString() else "",
            color = when {
                summary.isSelected -> Color.White
                !summary.isInDisplayedMonth -> palette.onBackground.copy(alpha = 0.2f)
                else -> palette.onBackground
            },
            fontSize = 13.sp,
            fontWeight = if (summary.isSelected) FontWeight.Bold else FontWeight.Normal
        )
    }
}
```

- [ ] **Step 2: Wire into MainScreen**

In `MainScreen.kt`, add a `if (showCalendar)` block before the closing brace:

```kotlin
if (showCalendar) {
    CalendarSheet(
        vm = vm,
        palette = palette,
        onDismiss = { showCalendar = false }
    )
}
```

Add import: `import academy.glasscode.piday.features.calendar.CalendarSheet`

- [ ] **Step 3: Run — tap calendar icon, expect heat map sheet**

- [ ] **Step 4: Commit**

```bash
git add app/src/main/java/academy/glasscode/piday/features/calendar/
git commit -m "feat(android): CalendarSheet — heat map grid with PiHeatLevel colors"
```

---

## Phase 3: Supporting Features

### Task 13: DetailSheet

**Files:**
- Create: `app/src/main/java/academy/glasscode/piday/features/detail/DetailSheet.kt`

- [ ] **Step 1: Create DetailSheet.kt**

```kotlin
// features/detail/DetailSheet.kt
package academy.glasscode.piday.features.detail

import academy.glasscode.piday.core.domain.*
import academy.glasscode.piday.design.AppPalette
import academy.glasscode.piday.features.main.AppViewModel
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.time.format.DateTimeFormatter
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DetailSheet(
    vm: AppViewModel,
    palette: AppPalette,
    onDismiss: () -> Unit,
    onOpenPreferences: () -> Unit
) {
    val selectedDate by vm.selectedDate.collectAsStateWithLifecycle()
    val lookupSummary by vm.lookupSummary.collectAsStateWithLifecycle()
    val convention = vm.indexingConvention
    val formatter = DateTimeFormatter.ofPattern("MMMM d, yyyy", Locale.getDefault())

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = palette.background) {
        Column(modifier = Modifier.padding(horizontal = 24.dp)) {
            Text(
                text = selectedDate.format(formatter),
                style = MaterialTheme.typography.headlineSmall,
                color = palette.onBackground
            )

            Spacer(Modifier.height(16.dp))

            if (lookupSummary == null) {
                CircularProgressIndicator(color = palette.accent)
            } else {
                val summary = lookupSummary!!
                if (summary.bestMatch != null) {
                    val best = summary.bestMatch
                    val displayPos = convention.displayPosition(best.storedPosition)
                    Text(
                        "Position: $displayPos",
                        color = palette.accent,
                        style = MaterialTheme.typography.titleLarge
                    )
                    Text(
                        "Format: ${best.format.displayName}",
                        color = palette.onBackground.copy(alpha = 0.7f)
                    )
                    Text(
                        "Sequence: ${best.query}",
                        color = palette.onBackground,
                        fontFamily = FontFamily.Monospace
                    )
                } else {
                    Text(
                        "Not found in first 5 billion digits",
                        color = palette.onBackground.copy(alpha = 0.6f)
                    )
                }

                Spacer(Modifier.height(16.dp))

                // All format results
                summary.matches.forEach { match ->
                    Row(modifier = Modifier.fillMaxWidth().padding(vertical = 2.dp)) {
                        Text(
                            match.format.displayName,
                            modifier = Modifier.weight(1f),
                            color = palette.onBackground.copy(alpha = 0.7f),
                            fontFamily = FontFamily.Monospace
                        )
                        Text(
                            if (match.found) match.storedPosition?.let { convention.displayPosition(it).toString() } ?: "–" else "Not found",
                            color = if (match.found) palette.onBackground else palette.onBackground.copy(alpha = 0.4f),
                            fontFamily = FontFamily.Monospace
                        )
                    }
                }
            }

            Spacer(Modifier.height(16.dp))

            OutlinedButton(onClick = onOpenPreferences, modifier = Modifier.fillMaxWidth()) {
                Text("Settings", color = palette.accent)
            }

            Spacer(Modifier.height(32.dp))
        }
    }
}
```

- [ ] **Step 2: Wire into MainScreen** (similar to calendar, add `if (showDetail)` block)

- [ ] **Step 3: Commit**

```bash
git add app/src/main/java/academy/glasscode/piday/features/detail/DetailSheet.kt
git commit -m "feat(android): DetailSheet — match results, position display, format breakdown"
```

---

### Task 14: Services (PreferencesStore + SavedDatesStore)

**Files:**
- Create: `app/src/main/java/academy/glasscode/piday/services/PreferencesStore.kt`
- Create: `app/src/main/java/academy/glasscode/piday/services/SavedDatesStore.kt`

- [ ] **Step 1: Create PreferencesStore.kt**

```kotlin
// services/PreferencesStore.kt
package academy.glasscode.piday.services

import academy.glasscode.piday.core.domain.IndexingConvention
import academy.glasscode.piday.core.domain.SearchFormatPreference
import academy.glasscode.piday.design.AppThemeOption
import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.*
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore("piday_prefs")

// WHY DataStore: replaces iOS UserDefaults. It's async, coroutine-friendly, and
// avoids the main-thread blocking that SharedPreferences can cause.
class PreferencesStore(private val context: Context) {
    companion object {
        val THEME          = stringPreferencesKey("theme")
        val FORMAT_PREF    = stringPreferencesKey("format_pref")
        val INDEXING       = stringPreferencesKey("indexing")
    }

    val themeFlow: Flow<AppThemeOption> = context.dataStore.data.map { prefs ->
        prefs[THEME]?.let { runCatching { AppThemeOption.valueOf(it) }.getOrNull() } ?: AppThemeOption.SLATE
    }

    val formatPrefFlow: Flow<SearchFormatPreference> = context.dataStore.data.map { prefs ->
        prefs[FORMAT_PREF]?.let { runCatching { SearchFormatPreference.valueOf(it) }.getOrNull() } ?: SearchFormatPreference.INTERNATIONAL
    }

    val indexingFlow: Flow<IndexingConvention> = context.dataStore.data.map { prefs ->
        prefs[INDEXING]?.let { runCatching { IndexingConvention.valueOf(it) }.getOrNull() } ?: IndexingConvention.ONE_BASED
    }

    suspend fun setTheme(theme: AppThemeOption) {
        context.dataStore.edit { it[THEME] = theme.name }
    }

    suspend fun setFormatPreference(pref: SearchFormatPreference) {
        context.dataStore.edit { it[FORMAT_PREF] = pref.name }
    }

    suspend fun setIndexingConvention(convention: IndexingConvention) {
        context.dataStore.edit { it[INDEXING] = convention.name }
    }
}
```

- [ ] **Step 2: Create SavedDatesStore.kt**

```kotlin
// services/SavedDatesStore.kt
package academy.glasscode.piday.services

import academy.glasscode.piday.core.domain.SavedDate
import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences

private val Context.savedDatesStore: DataStore<Preferences> by preferencesDataStore("saved_dates")

class SavedDatesStore(private val context: Context) {
    private val KEY = stringPreferencesKey("saved_dates_json")
    private val json = Json { ignoreUnknownKeys = true }

    val savedDates: Flow<List<SavedDate>> = context.savedDatesStore.data.map { prefs ->
        prefs[KEY]?.let {
            runCatching { json.decodeFromString<List<SavedDate>>(it) }.getOrElse { emptyList() }
        } ?: emptyList()
    }

    suspend fun save(dates: List<SavedDate>) {
        context.savedDatesStore.edit { it[KEY] = json.encodeToString(dates) }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add app/src/main/java/academy/glasscode/piday/services/
git commit -m "feat(android): PreferencesStore + SavedDatesStore via DataStore"
```

---

### Task 15: PreferencesScreen

**Files:**
- Create: `app/src/main/java/academy/glasscode/piday/features/preferences/PreferencesScreen.kt`

- [ ] **Step 1: Create PreferencesScreen.kt**

```kotlin
// features/preferences/PreferencesScreen.kt
package academy.glasscode.piday.features.preferences

import academy.glasscode.piday.core.domain.IndexingConvention
import academy.glasscode.piday.core.domain.SearchFormatPreference
import academy.glasscode.piday.design.AppPalette
import academy.glasscode.piday.design.AppThemeOption
import academy.glasscode.piday.features.main.AppViewModel
import academy.glasscode.piday.services.PreferencesStore
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PreferencesScreen(
    vm: AppViewModel,
    palette: AppPalette,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current
    val prefsStore = remember { PreferencesStore(context) }
    val scope = rememberCoroutineScope()

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = palette.background) {
        LazyColumn(modifier = Modifier.padding(horizontal = 24.dp)) {
            item {
                Text("Theme", style = MaterialTheme.typography.titleSmall,
                     color = palette.onBackground.copy(alpha = 0.6f))
                Spacer(Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    AppThemeOption.entries.take(2).forEach { theme ->
                        FilterChip(
                            selected = false, // TODO: wire to prefsStore.themeFlow
                            onClick = { scope.launch { prefsStore.setTheme(theme) } },
                            label = { Text(theme.name.lowercase().replaceFirstChar { it.uppercase() }) }
                        )
                    }
                }
            }

            item {
                Spacer(Modifier.height(16.dp))
                Text("Date Format", style = MaterialTheme.typography.titleSmall,
                     color = palette.onBackground.copy(alpha = 0.6f))
                Spacer(Modifier.height(8.dp))
                SearchFormatPreference.entries.forEach { pref ->
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(pref.title, color = palette.onBackground)
                        RadioButton(
                            selected = vm.searchPreference == pref,
                            onClick = {
                                vm.setSearchPreference(pref)
                                scope.launch { prefsStore.setFormatPreference(pref) }
                            }
                        )
                    }
                }
            }

            item {
                Spacer(Modifier.height(16.dp))
                Text("Position Display", style = MaterialTheme.typography.titleSmall,
                     color = palette.onBackground.copy(alpha = 0.6f))
                Spacer(Modifier.height(8.dp))
                IndexingConvention.entries.forEach { convention ->
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Column {
                            Text(convention.label, color = palette.onBackground)
                            Text(convention.explainer,
                                 color = palette.onBackground.copy(alpha = 0.5f),
                                 style = MaterialTheme.typography.bodySmall)
                        }
                        RadioButton(
                            selected = vm.indexingConvention == convention,
                            onClick = {
                                vm.setIndexingConvention(convention)
                                scope.launch { prefsStore.setIndexingConvention(convention) }
                            }
                        )
                    }
                }
            }

            item { Spacer(Modifier.height(48.dp)) }
        }
    }
}
```

- [ ] **Step 2: Wire into DetailSheet** — replace the `OutlinedButton("Settings")` onClick to pass `onOpenPreferences`; wire in MainScreen to show `PreferencesScreen`.

- [ ] **Step 3: Commit**

```bash
git add app/src/main/java/academy/glasscode/piday/features/preferences/PreferencesScreen.kt
git commit -m "feat(android): PreferencesScreen — theme, date format, indexing convention"
```

---

### Task 16: SavedDatesSheet + FreeSearchSheet

**Files:**
- Create: `app/src/main/java/academy/glasscode/piday/features/saveддates/SavedDatesSheet.kt`
- Create: `app/src/main/java/academy/glasscode/piday/features/freesearch/FreeSearchSheet.kt`
- Create: `app/src/main/java/academy/glasscode/piday/features/freesearch/FreeSearchViewModel.kt`

- [ ] **Step 1: Create FreeSearchViewModel.kt**

```kotlin
// features/freesearch/FreeSearchViewModel.kt
package academy.glasscode.piday.features.freesearch

import academy.glasscode.piday.core.repository.PiLiveLookupService
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class FreeSearchViewModel : ViewModel() {
    private val liveLookup = PiLiveLookupService()
    private val _result = MutableStateFlow<Pair<Int, String>?>(null)
    val result: StateFlow<Pair<Int, String>?> = _result.asStateFlow()
    private val _isSearching = MutableStateFlow(false)
    val isSearching: StateFlow<Boolean> = _isSearching.asStateFlow()
    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    private var searchJob: Job? = null

    // WHY 400ms debounce: mirrors iOS FreeSearchViewModel — avoids hammering the API
    // on every keystroke while keeping the UX snappy.
    fun onQueryChange(query: String) {
        searchJob?.cancel()
        if (query.length < 2) {
            _result.value = null
            _error.value = null
            return
        }
        searchJob = viewModelScope.launch {
            delay(400)
            if (!isActive) return@launch
            _isSearching.value = true
            _error.value = null
            try {
                _result.value = liveLookup.searchDigits(query)
            } catch (e: Exception) {
                _error.value = e.message
            } finally {
                _isSearching.value = false
            }
        }
    }

    fun clear() {
        searchJob?.cancel()
        _result.value = null
        _error.value = null
        _isSearching.value = false
    }
}
```

- [ ] **Step 2: Create FreeSearchSheet.kt**

```kotlin
// features/freesearch/FreeSearchSheet.kt
package academy.glasscode.piday.features.freesearch

import academy.glasscode.piday.design.AppPalette
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FreeSearchSheet(
    palette: AppPalette,
    onDismiss: () -> Unit,
    vm: FreeSearchViewModel = viewModel()
) {
    var query by remember { mutableStateOf("") }
    val result by vm.result.collectAsStateWithLifecycle()
    val isSearching by vm.isSearching.collectAsStateWithLifecycle()
    val error by vm.error.collectAsStateWithLifecycle()

    DisposableEffect(Unit) { onDispose { vm.clear() } }

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = palette.background) {
        Column(modifier = Modifier.padding(24.dp)) {
            Text("Search Pi Digits", style = MaterialTheme.typography.titleLarge,
                 color = palette.onBackground)
            Spacer(Modifier.height(16.dp))
            OutlinedTextField(
                value = query,
                onValueChange = { new ->
                    query = new.filter { it.isDigit() }
                    vm.onQueryChange(query)
                },
                label = { Text("Digit sequence") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = palette.accent)
            )
            Spacer(Modifier.height(16.dp))
            when {
                isSearching -> CircularProgressIndicator(color = palette.accent)
                error != null -> Text(error!!, color = MaterialTheme.colorScheme.error)
                result != null -> {
                    val (position, excerpt) = result!!
                    Text("Found at position $position", color = palette.accent,
                         style = MaterialTheme.typography.titleMedium)
                    Spacer(Modifier.height(8.dp))
                    // Show a snippet of the excerpt around the match
                    val snippetStart = maxOf(0, excerpt.length / 2 - 20)
                    val snippet = excerpt.substring(snippetStart, minOf(snippetStart + 60, excerpt.length))
                    Text("…$snippet…", color = palette.onBackground, fontFamily = FontFamily.Monospace)
                }
                query.length >= 2 -> Text("Not found in first 5 billion digits",
                                          color = palette.onBackground.copy(alpha = 0.5f))
            }
            Spacer(Modifier.height(32.dp))
        }
    }
}
```

- [ ] **Step 3: Create SavedDatesSheet.kt**

```kotlin
// features/saveддates/SavedDatesSheet.kt
package academy.glasscode.piday.features.saveddates

import academy.glasscode.piday.core.domain.SavedDate
import academy.glasscode.piday.design.AppPalette
import academy.glasscode.piday.features.main.AppViewModel
import academy.glasscode.piday.services.SavedDatesStore
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch
import java.time.format.DateTimeFormatter
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SavedDatesSheet(
    vm: AppViewModel,
    palette: AppPalette,
    onDismiss: () -> Unit,
    onDateSelected: (java.time.LocalDate) -> Unit
) {
    val context = LocalContext.current
    val store = remember { SavedDatesStore(context) }
    val scope = rememberCoroutineScope()
    var savedDates by remember { mutableStateOf<List<SavedDate>>(emptyList()) }
    val formatter = DateTimeFormatter.ofPattern("MMMM d, yyyy", Locale.getDefault())

    LaunchedEffect(Unit) {
        store.savedDates.collectLatest { savedDates = it }
    }

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = palette.background) {
        Column(modifier = Modifier.padding(24.dp)) {
            Text("Saved Dates", style = MaterialTheme.typography.titleLarge,
                 color = palette.onBackground)
            Spacer(Modifier.height(16.dp))

            if (savedDates.isEmpty()) {
                Text("No saved dates yet. Bookmark a date from the detail view.",
                     color = palette.onBackground.copy(alpha = 0.5f))
            } else {
                LazyColumn {
                    items(savedDates, key = { it.id }) { saved ->
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(saved.label, color = palette.onBackground)
                                Text(saved.date.format(formatter),
                                     color = palette.onBackground.copy(alpha = 0.6f),
                                     style = MaterialTheme.typography.bodySmall)
                            }
                            IconButton(onClick = {
                                scope.launch {
                                    store.save(savedDates.filter { it.id != saved.id })
                                }
                            }) {
                                Icon(Icons.Default.Delete, "Delete",
                                     tint = MaterialTheme.colorScheme.error)
                            }
                        }
                        HorizontalDivider(color = palette.border)
                    }
                }
            }
            Spacer(Modifier.height(32.dp))
        }
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add app/src/main/java/academy/glasscode/piday/features/
git add app/src/main/java/academy/glasscode/piday/services/
git commit -m "feat(android): FreeSearch, SavedDates sheets + FreeSearchViewModel"
```

---

### Task 17: Share card

**Files:**
- Create: `app/src/main/java/academy/glasscode/piday/features/share/ShareCard.kt`

- [ ] **Step 1: Create ShareCard.kt**

```kotlin
// features/share/ShareCard.kt
package academy.glasscode.piday.features.share

import academy.glasscode.piday.core.domain.BestPiMatch
import academy.glasscode.piday.design.AppPalette
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileOutputStream
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

// WHY: ShareCard is a purely decorative Composable used both for display
// and for rendering to bitmap. On Android we render a Composable to a bitmap
// using Picture + Canvas instead of iOS's ImageRenderer.

@Composable
fun ShareCardView(
    date: LocalDate,
    bestMatch: BestPiMatch?,
    palette: AppPalette,
    modifier: Modifier = Modifier
) {
    val formatter = DateTimeFormatter.ofPattern("MMMM d, yyyy", Locale.getDefault())

    Box(
        modifier = modifier
            .aspectRatio(1.6f)
            .background(palette.background, RoundedCornerShape(16.dp))
            .padding(24.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                "π",
                fontSize = 48.sp,
                color = palette.accent,
                fontWeight = FontWeight.Bold
            )
            Spacer(Modifier.height(8.dp))
            Text(
                date.format(formatter),
                color = palette.onBackground,
                fontSize = 20.sp,
                fontWeight = FontWeight.Medium
            )
            if (bestMatch != null) {
                Spacer(Modifier.height(4.dp))
                Text(
                    "appears at position ${bestMatch.storedPosition}",
                    color = palette.onBackground.copy(alpha = 0.7f),
                    fontSize = 14.sp
                )
                Spacer(Modifier.height(8.dp))
                Text(
                    bestMatch.query,
                    color = palette.accent,
                    fontFamily = FontFamily.Monospace,
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold
                )
            }
            Spacer(Modifier.height(12.dp))
            Text("piday.app", color = palette.onBackground.copy(alpha = 0.4f), fontSize = 12.sp)
        }
    }
}

// WHY a helper function rather than a ViewModel method: sharing is a one-shot
// imperative action triggered by a button tap. No state to observe.
fun shareCard(context: Context, bitmap: Bitmap) {
    val file = File(context.cacheDir, "piday_share.png")
    FileOutputStream(file).use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
    val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "image/png"
        putExtra(Intent.EXTRA_STREAM, uri)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    context.startActivity(Intent.createChooser(intent, "Share PiDay"))
}
```

- [ ] **Step 2: Add FileProvider to AndroidManifest.xml** (required to share files)

Inside `<application>`:
```xml
<provider
    android:name="androidx.core.content.FileProvider"
    android:authorities="${applicationId}.fileprovider"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/file_paths" />
</provider>
```

Create `app/src/main/res/xml/file_paths.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<paths>
    <cache-path name="shared_images" path="." />
</paths>
```

- [ ] **Step 3: Commit**

```bash
git add app/src/main/java/academy/glasscode/piday/features/share/
git add app/src/main/AndroidManifest.xml
git add app/src/main/res/xml/
git commit -m "feat(android): ShareCard composable + FileProvider for bitmap sharing"
```

---

## Phase 4: Polish

### Task 18: App icon + final wiring

- [ ] **Step 1: Add a placeholder icon** — in Android Studio, right-click `res` → New → Image Asset → use the π character as a text icon with the slate blue background.

- [ ] **Step 2: Wire all sheets into MainScreen** — ensure all `show*` state variables exist and the corresponding sheets are rendered conditionally.

- [ ] **Step 3: Wire saved-date toggle** — in DetailSheet, add a bookmark icon that reads/writes `SavedDatesStore`.

- [ ] **Step 4: Manual smoke test checklist**
  - [ ] App launches, shows Pi canvas with today's date
  - [ ] Swipe left/right changes date, canvas updates
  - [ ] Calendar icon → heat map shows correct colors
  - [ ] Tap a date → navigates to that date, sheet dismisses
  - [ ] Detail icon → shows position, all format rows
  - [ ] Settings → format preference change updates canvas
  - [ ] Free search → type "314159" → returns position
  - [ ] Share → share sheet appears with card image

- [ ] **Step 5: Final commit**

```bash
git add .
git commit -m "feat(android): PiDay Android v1.0 — full port complete"
```

---

## Play Store submission checklist (after all tasks complete)

- [ ] Bump `versionCode` and `versionName` in `app/build.gradle.kts`
- [ ] Enable minification (`isMinifyEnabled = true`) and test release build
- [ ] Generate upload keystore: `keytool -genkey -v -keystore piday.jks -keyAlias piday -keyalg RSA -keysize 2048 -validity 10000`
- [ ] Sign release build via `signingConfigs` block in `app/build.gradle.kts`
- [ ] Create Play Console account (one-time $25 fee)
- [ ] Upload AAB: `./gradlew bundleRelease`
- [ ] Screenshot set: Android Studio Device Mirror or emulator screenshots at 1080×1920 and 2560×1600 (tablet)
- [ ] Privacy policy URL (required — can reuse iOS one)
