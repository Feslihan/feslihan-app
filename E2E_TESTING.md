# E2E UI Tests (iOS)

End-to-end XCUITest suite that drives the real app in an iOS simulator against
an **ephemeral local backend** (fresh Postgres + the real Express server + the
real Anthropic API). Runs on demand in GitHub Actions via the
**"E2E iOS UI Tests"** workflow (`.github/workflows/e2e-ios.yml`).

## What gets tested

| Suite | Flow | Backend endpoints exercised |
|---|---|---|
| `A01_AuthFlowTests` | Landing screen, Clerk sign-in sheet, full test-account sign-in | `POST /users/sync` (via sign-in) |
| `A02_HomeHubTests` | 5-mode hub, live pantry counter, account sheet | `GET /users/:id/pantry`, `GET /users/:id/shopping-list` |
| `A03_RecipeBrowseTests` | Tariflerim list, search, recipe detail tabs | `GET /users/:id/recipes` |
| `A04_PantryTests` | Seeded pantry, search, add via picker, delete via context menu | `GET/POST/DELETE /users/:id/pantry`, `GET /ingredients` |
| `A05_ShoppingListTests` | Add, check off, "Kilere Ekle", delete | `GET/POST/PUT/DELETE /users/:id/shopping-list` |
| `A06_WhatToEatTests` | 4-step wizard, suggestion cards, save/skip | `GET /users/:id/recipes`, `GET /users/:id/pantry` |
| `A07_MealPlanAITests` | **Real Claude** meal-plan generation, save, saved-plans list | `POST /ai/meal-plan`, `POST /meal-plans`, `GET /users/:id/meal-plans` |

Suites are ordered (`A01`…`A07`): the auth suite runs first and the Clerk
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
- The Clerk auth sheet is ClerkKitUI's prebuilt component — its labels depend
  on the ClerkKit version/locale. `performClerkSignIn()` tries several
  continue-button labels; if a ClerkKit upgrade breaks sign-in, start there.
- Tests assume the seeded platform recipes exist (e.g. "Mercimek Çorbası" from
  `feslihan-backend/src/seed-recipes.ts`). If seed recipes change, update
  `A03_RecipeBrowseTests`.
- Each run starts from a **fresh database**, so test data never pollutes
  production. The simulator keychain persists within one workflow run only.
