# Feslihan — Android

Native Android port of the Feslihan iOS app (`../Feslihan`). Uses the **same
backend** (`api.feslihan.com.tr`); see [`docs/API_CONTRACT.md`](docs/API_CONTRACT.md).

## Stack
- **Kotlin** + **Jetpack Compose** (Material 3) — mirrors SwiftUI.
- **Navigation Compose** — screen graph.
- **Hilt** — dependency injection.
- **Retrofit + OkHttp + kotlinx.serialization** — networking (snake_case JSON).
- **Room** — local persistence (mirrors SwiftData `Recipe`).
- **DataStore** — lightweight prefs/flags.
- **WorkManager** — daily "Yarın ne pişirsem?" local notification.
- **Coil** — image loading.
- **RevenueCat** — subscriptions (mirrors iOS). **Clerk** — auth.

## Module layout
```
app/src/main/java/com/feslihan/app/
  ui/theme/        Design system ported from iOS Theme.swift (DS enum)
  ui/navigation/   Nav graph + routes
  ui/screens/      Compose screens (one package per iOS View)
  data/model/      @Serializable DTOs + domain models
  data/local/      Room entities, DAOs, database
  data/remote/     Retrofit API interfaces, auth interceptor
  data/repository/ Repositories bridging remote + local
  di/              Hilt modules
```

## Design system (parity with iOS)
"Modern Kitchen Editorial": white bg, hairline `#E5E5E5` borders, **no shadows**,
radius **8** everywhere. Basil accent `#23834A` (tint `#E6F3EA`); supporting
tomato `#D93A2B`, saffron `#F2A516`, eggplant `#6B2D6B`. Serif (semibold) titles,
sans body, italic serif for notes. Light + dark, tokens in `ui/theme/Color.kt`.

## Status (incremental port)
This is an in-progress 1:1 port. Done / in progress / pending tracked in the PR.
Build foundation (Gradle, theme, models, network layer, nav skeleton) lands first;
screens follow one iOS View at a time.

## Setup notes / open items
- **Gradle wrapper**: run `gradle wrapper --gradle-version 8.11` once locally to
  generate `gradlew` + `gradle/wrapper/` (binary jar is not committed here).
- **Auth (Clerk)**: pin the real Clerk Android SDK coordinate in
  `gradle/libs.versions.toml` (`clerk` version is a placeholder) and wire
  `Clerk.initialize(...)` in `FeslihanApp` + a token provider for the auth interceptor.
- **Subscriptions**: set the RevenueCat **Google Play** public key and configure
  the `feslihan_plus` / `feslihan_pro` entitlements in the RevenueCat dashboard.
- **Push**: backend sends **APNs** today (`feslihan-backend/src/apns.ts`). Android
  needs **FCM** — add an FCM sender server-side and a device-registration variant
  of `POST /devices` carrying the FCM token.
- **Secrets**: `API_BASE_URL` is a `BuildConfig` field; keys (Clerk, RevenueCat)
  should come from `local.properties` / CI secrets, never committed.

## Build
```
cd feslihan-android
./gradlew assembleDebug
```
(Requires the Android SDK + the wrapper generated as above.)
