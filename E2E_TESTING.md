# E2E UI Tests (iOS)

End-to-end XCUITest suite that drives the real app in an iOS simulator against
an **ephemeral local backend** (fresh Postgres + the real Express server + the
real Anthropic API). Runs on demand in GitHub Actions via the
**"E2E iOS UI Tests"** workflow (`.github/workflows/e2e-ios.yml`).

## What gets tested

| Suite | Flow | Backend endpoints exercised |
|---|---|---|
| `A01_AuthFlowTests` | Landing screen, Clerk sign-in sheet, full test-account sign-in | `POST /users/sync` (via sign-in) |
| `A02_HomeHubTests` | 5-mode hub, live pantry counter, hero card (plan özeti/CTA), account sheet | `GET /users/:id/pantry`, `GET /users/:id/shopping-list`, `GET /users/:id/meal-plans` |
| `A03_RecipeBrowseTests` | Tariflerim list, search, Denediklerim/Beğendiklerim chips, filter sheet, detail tabs | `GET /users/:id/recipes`, `GET /users/:id/reviews` |
| `A04_PantryTests` | Seeded pantry, search (+no-result), add via picker, delete, move-to-shopping, bubble sheet | `GET/POST/DELETE /users/:id/pantry`, `GET /ingredients` |
| `A05_ShoppingListTests` | Add, check/uncheck, "Kilere Ekle", delete, bubble sheet | `GET/POST/PUT/DELETE /users/:id/shopping-list` |
| `A06_WhatToEatTests` | 4-step wizard (noLimit + pantryOnly), save/skip, deck sonu, boş durum | `GET /users/:id/recipes`, `GET /users/:id/pantry` |
| `A07_MealPlanAITests` | **Real Claude** meal-plan generation, save, saved-plans list | `POST /ai/meal-plan`, `POST /meal-plans`, `GET /users/:id/meal-plans` |
| `A08_AddRecipeTests` | Tarif ekleme: boş/geçersiz/desteklenmeyen link hataları, **gerçek web scrape** (nefisyemektarifleri + Claude), duplicate-URL cache yolu | `POST /recipes/scrape-web`, `POST /recipes`, `GET /recipes/lookup` |
| `A09_RecipeDetailTests` | Favori ekle/çıkar, porsiyon çarpanı, Besin sekmesi, yorum ekle/sil, Plana Ekle sayfası | `PUT …/favorite`, `POST/DELETE reviews`, `GET /users/:id/reviews` |
| `A10_CookingModeTests` | Pişirme modu: tüm adımlar, geri/ileri, Tamamlandı → yorum, kapatma | — (yerel akış + review lookup) |
| `A11_FoldersTests` | Klasör oluştur, tarif taşı, klasörden çıkar, klasör sil | `POST/DELETE /folders`, `PUT …/folder`, `GET /users/:id/folders` |
| `A12_ManualMealPlanTests` | Manuel plan: ad + gün sayısı + öğün/tarif ekleme, kaydet, detay sekmeleri, sil | `POST/DELETE /meal-plans`, `GET /users/:id/meal-plans` |
| `A13_AccountSettingsTests` | Hesap sayfası kısayolları, Ayarlar bölümleri (çıkış/silmeye dokunmaz) | — |
| `A14_OnboardingTests` | `-hasCompletedOnboarding NO` ile zorlanan onboarding: iki adım + CTA sheet'leri | — |

Bilinçli olarak otomatize edilmeyenler: video (Instagram/TikTok) tarif ekleme
mutlu yolu (oEmbed uçları CI IP'lerini engeller — validasyon hataları
kapsanıyor), bubble oyununda balon patlatma (hedefler sürekli hareket ediyor —
liste picker'ı deterministik ekleme yolunu kapsıyor), paywall (Debug build'de
plan `pro`'ya sabit), pantry gate (seed 35 malzeme ile gate'i geçiyor; gate
UI'ı PantryGateView'da identifier'lı, <30 malzemeli bir kullanıcı gerektirir),
Çıkış Yap / Hesabı Sil (oturumu/hesabı bozar).

Suites are ordered (`A01`…`A14`): the auth suite runs first and the Clerk
session persists in the simulator keychain for the rest of the run. Every other
suite still calls `ensureSignedInAtHome()`, so individual suites can also run
alone via the workflow's `test_filter` input
(e.g. `FeslihanUITests/A04_PantryTests`).

## One-time setup

### 1. Clerk test account

The app uses a Clerk **development** instance (`pk_test_…`), which supports
[test mode](https://clerk.com/docs/testing/test-emails-and-phones): any email
with the `+clerk_test` subaddress signs in with the fixed verification code
**424242** and no real email is sent.

1. In the app (or Clerk dashboard → Users → Create user), create a user such as
   `feslihan.e2e+clerk_test@example.com`. Give it a password if password auth
   is enabled on the instance — password sign-in is the most robust path for
   the UI tests.
2. Copy the user's ID (`user_…`) from the Clerk dashboard.

### 2. GitHub repository secrets

Settings → Secrets and variables → Actions:

| Secret | Value |
|---|---|
| `CLERK_SECRET_KEY` | `sk_test_…` secret key of the same dev instance |
| `ANTHROPIC_API_KEY` | API key used by `/ai/*` routes (costs a few cents per run) |
| `E2E_CLERK_USER_ID` | the test user's `user_…` id |
| `E2E_CLERK_EMAIL` | the test user's email |
| `E2E_CLERK_PASSWORD` | the test user's password (omit to use OTP 424242) |

> The backend verifies session JWTs against Clerk's API, so the CI backend and
> the app must point at the **same** Clerk dev instance. The publishable key is
> hardcoded in `FeslihanApp.swift`; `CLERK_SECRET_KEY` must belong to it.

### 3. Run it

GitHub → Actions → **E2E iOS UI Tests** → *Run workflow*. Optionally set
`test_filter` to a single suite/test. The full run takes roughly 30–45 minutes
(SPM resolution + build dominate; the AI meal-plan test waits up to 4 minutes
for Claude).

On failure, download the `xcresult` artifact (open with Xcode: screenshots and
UI hierarchy per failure) and `backend-log`.

## How the pieces fit

```
macos-15 runner
├── postgresql@16 (Homebrew)  ← fresh DB "feslihan_e2e", drizzle-kit push
├── feslihan-backend (npm run start, port 3000)
│   ├── boot seeding: tags, platform recipes, ingredients
│   ├── CLERK_SECRET_KEY → verifies real Clerk JWTs from the app
│   └── ANTHROPIC_API_KEY → real Claude for /ai/meal-plan
├── scripts/seed-e2e.ts  ← test user (plan=pro), platform recipes mapped,
│                           35 pantry items (app gates most modes below 30)
└── iPhone 16 simulator
    └── Feslihan.app with FESLIHAN_API_URL=http://127.0.0.1:3000
        (launch-environment override in APIService.baseURL)
```

- The Xcode project is **XcodeGen-generated**: the `FeslihanUITests` target and
  the shared `Feslihan` scheme live in `project.yml`; CI runs
  `xcodegen generate` before building. If you add test files locally, re-run
  `xcodegen generate`.
- Test configuration flows via `TEST_RUNNER_*` environment variables on
  `xcodebuild`, read in `FeslihanUITests/FeslihanUITestCase.swift` (`TestEnv`),
  and forwarded to the app through `launchEnvironment`.
- The test user is seeded as `pro`, so the meal-plan premium gate and the AI
  monthly quota never block the run. (Debug builds also hardcode the `pro`
  plan client-side in `SubscriptionService`.)

## Running locally

```bash
# 1. Postgres + backend
createdb feslihan_e2e
cd feslihan-backend
DATABASE_URL="postgresql://localhost/feslihan_e2e?sslmode=disable" npm run db:migrate
# .env needs DATABASE_URL (with sslmode=disable), CLERK_SECRET_KEY, ANTHROPIC_API_KEY
npm run start &
E2E_CLERK_USER_ID=user_xxx node --env-file=.env --import tsx/esm scripts/seed-e2e.ts

# 2. Tests
cd ..
xcodegen generate
TEST_RUNNER_FESLIHAN_API_URL="http://127.0.0.1:3000" \
TEST_RUNNER_E2E_CLERK_EMAIL="feslihan.e2e+clerk_test@example.com" \
TEST_RUNNER_E2E_CLERK_PASSWORD="…" \
xcodebuild test -project Feslihan.xcodeproj -scheme Feslihan \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Gotchas / maintenance

- **Accessibility identifiers** are the contract between app and tests
  (`auth.*`, `home.mode.*`, `pantry.*`, `shopping.*`, `whatToEat.*`,
  `mealPrep.*`, `mealPlans.*`, `onboarding.*`, `backButton`). If you rename or
  restructure a screen, keep the identifier on the equivalent control.
- The Clerk auth sheet is ClerkKitUI's prebuilt component and is HOSTILE to
  naive XCUITest queries. Hard-won facts baked into `performClerkSignIn()`:
  - Its inputs are **not** exposed as `textFields`/`secureTextFields` — the
    whole sheet reports zero of each. The placeholders surface as
    `StaticText`; tap their frame, then type into the app's first responder.
  - Typing can silently no-op if the software keyboard isn't up yet; the
    helper waits for `app.keyboards` and verifies via Continue's
    enabled-state (it stays disabled while the field is empty), retrying.
  - Clerk **persists half-finished sign-in attempts** in the keychain and
    pre-fills the identifier on relaunch — always clear before typing
    (`clearAndType`). Tap the field body at ~35% width: password fields have
    a show/hide icon at the right edge that swallows edge taps.
  - Clerk remembers the last-used second factor and may show "Enter password"
    instead of the code screen. The helper always switches to the EMAIL CODE
    path ("Use another method" → email code): that screen auto-focuses its
    boxes with the keyboard up, and test mode accepts 424242.
  - The Clerk dev instance must have **test mode enabled**
    (`PATCH https://api.clerk.com/v1/instance {"test_mode": true}`), or
    424242 is rejected and a real email is sent.
- Tests assume the seeded platform recipes exist (e.g. "Mercimek Çorbası" from
  `feslihan-backend/src/seed-recipes.ts`). If seed recipes change, update
  `A03_RecipeBrowseTests`.
- **SwiftUI element-type traps** (cost a full debugging day — read before
  touching the tests):
  - Underlined tab bars (`RecipeDetailView`, `SavedPlanDetailSheet`) expose
    their tabs as **buttons**, not staticTexts — the Button swallows its
    inner Text. `app.staticTexts["Malzemeler"]` never matches on those
    screens; use `app.buttons[...]`.
  - The home hero card (Haftalık Plan) **ignores synthesized taps** in the
    simulator (real finger taps work). Tests enter the saved-plans screen via
    the DEBUG-only `-e2eStartMealPrep` launch argument
    (`relaunchIntoMealPrep()` helper) after two tap attempts.
  - Never nest an interactive `Menu` inside a `Button`'s label — the outer
    button swallows the menu's taps (fixed in `SavedMealPlansView`; plan
    cards now use `onTapGesture` + `contextMenu`). Long-press context menus
    are the reliable deletion pattern under XCUITest.
  - After returning to the hub, wait for the pantry counter (>= 30) before
    tapping gated modes — `assertHomeHub()` does this — or the 30-item
    pantry gate swallows the navigation.
  - `scrollTo(_:)` before tapping grid cells: lazy grids report offscreen
    cells as `exists == true`, and tapping one lands on whatever occupies
    those coordinates.
- Each run starts from a **fresh database**, so test data never pollutes
  production. The simulator keychain persists within one workflow run only.
