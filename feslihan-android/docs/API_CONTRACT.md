# Feslihan Backend API Contract (Android port reference)

Derived from the iOS client (`Feslihan/Services/*.swift`) and backend
(`feslihan-backend/src/*`). The Android app targets the **same backend** —
no backend rewrite, one addition (FCM, see Notifications).

## Base URL & Auth
- Base URL (prod): `https://api.feslihan.com.tr` (expose as `BuildConfig.API_BASE_URL`).
- Auth: Clerk session JWT as `Authorization: Bearer <jwt>` on **every** request
  except the public allowlist. Token comes from the Clerk Android SDK session.
- Server derives the user id from the token, never the body — `:userId` path
  params are accepted but ignored server-side.
- Content-Type: `application/json`. **All JSON is snake_case.** Timestamps ISO-8601.
- Public (no auth): `GET /images/:folder/:file`, `GET /kosullar|/gizlilik|/kvkk`,
  `POST /webhooks/revenuecat` (server-only shared secret).

### Errors
- Standard: `{ "error": "<message>" }`. 401 `unauthorized`, 403 `forbidden`.
- Quota (402): `{ "error": "...", "code": "quota_exceeded" | "meal_plan_quota_exceeded" | "premium_required" }`.
- 400 validation, 404 not found, 409 conflict (`already_friends`, `request_pending`), 502 upstream, 413 body too large.

## Endpoints

### Recipes
- `GET /recipes/lookup?url=<enc>` → `Recipe` or JSON `null`
- `GET /recipes` (`?requested_by=`, `?platform=`) → `[Recipe]`
- `GET /recipes/:id` → `Recipe`
- `GET /users/:userId/recipes` → `[Recipe]` (adds `folder_id`, `is_favorite`)
- `POST /recipes` (body `Recipe`) → `Recipe` (201 new / 200 existed)
- `DELETE /users/:userId/recipes/:recipeId` → 204
- `PUT /users/:userId/recipes/:recipeId/folder` `{folder_id: string?}` → `{ok:true}`
- `PUT /users/:userId/recipes/:recipeId/favorite` `{is_favorite: bool}` → `{ok, is_favorite}`
- `GET /recipes/:id/cost` → `RecipeCost`
- `POST /recipes/:recipeId/reviews` `{user_id, rating 1-5, comment?}` → `UserReview`
- `GET /recipes/:recipeId/reviews?limit=&offset=` → `[UserReview]` (limit 50, 1-100; offset 0)
- `GET /users/:userId/reviews` → `[UserReview]`
- `DELETE /reviews/:reviewId?user_id=` → `{ok:true}`
- `POST /recipes/scrape-web` `{url}` → `ScrapedRecipe` (fresh) or `Recipe{cached:true}`; 402 on quota

### AI (metered)
- `POST /ai/analyze` `{caption, transcription, frames:[b64], cover_image?:b64, audio?:b64}` (12MB cap) → `AnalyzeResult`; 402
- `POST /ai/meal-plan` `{people_count, meals_per_day, eating_styles:[], period, has_kids, kids_count, prep_style, budget, user_id}` (256KB cap) → `MealPlanResult`; 402 (`premium_required` for free)

### Meal plans (saved)
- `GET /users/:userId/meal-plans` → `[SavedPlan]`
- `POST /meal-plans` `{name?, plan(req), recipe_ids?, shopping_list?}` → `SavedPlan` (201)
- `PUT /meal-plans/:id` (any of name/plan/recipe_ids/shopping_list) → `SavedPlan`
- `DELETE /meal-plans/:id` → 204

### Pantry
- `GET /users/:userId/pantry` → `[PantryItem]`
- `POST /users/:userId/pantry` `{ingredient_names:[]}` → `{added:int}` (201)
- `DELETE /users/:userId/pantry/:ingredientId` → 204 (by ingredient_id)

### Shopping list
- `GET /users/:userId/shopping-list` → `[ShoppingItem]`
- `POST /users/:userId/shopping-list` `{ingredient_names:[]}` → `{added:int}` (201)
- `PUT /users/:userId/shopping-list/:itemId/check` `{is_checked}` → `{ok:true}`
- `DELETE /users/:userId/shopping-list/:itemId` → 204 (by row id)

### Folders
- `GET /users/:userId/folders` → `[Folder]`
- `POST /folders` `{user_id, name, emoji}` → `Folder` (201)
- `PUT /folders/:id` (name/emoji/sort_order) → `Folder`
- `DELETE /folders/:id` → 204

### Ingredients / tags / creators
- `GET /ingredients` → `[Ingredient]` (name is the id)
- `GET /tags` → `[string]`
- `GET /creators/:username` → `{username, platform, display_name, profile_picture_url}`
- `GET /creators/missing-pictures` → `[{username, platform}]`
- `PUT /creators/:username/picture` `{base64}` → `{ok:true}`

### Social / friends
- `GET /social/me` → `SocialMe`
- `GET /social/lookup?code=|?email=` → `SocialLookup` (404 none, 400 neither)
- `POST /social/requests` `{to_user_id}` → connection (201/200); 409 w/ code
- `GET /social/requests` → `FriendRequests {incoming, outgoing}`
- `POST /social/requests/:id/accept` → connection
- `DELETE /social/requests/:id` → 204
- `GET /social/friends` → `[Friend]`
- `DELETE /social/friends/:userId` → 204
- `GET /social/friends/:userId/recipes` → `[Recipe]` (403 if not friends)
- `POST /social/shares` `{to_user_id, recipe_id, message?}` → share + `recipient_has_recipe` (201/200); 403
- `GET /social/shares/inbox?status=pending|accepted|dismissed` → `[ShareInboxItem]`
- `POST /social/shares/:id/accept` → `{ok, already_saved}`
- `POST /social/shares/:id/dismiss` → `{ok:true}`
- Rate limits: social 20/min, lookup 15/min, ai+scrape 10/min.

### Subscription / quota / devices / user
- `GET /users/me/quota` → `QuotaStatus`
- `POST /users/sync` `{email?, name?, avatar_url?}` → `{ok:true}` (new users: 30-day unlimited trial + seeded recipes)
- `POST /devices` `{token, environment:"sandbox"|"production"}` → `{ok:true}` (APNs today; **add FCM equivalent for Android**)

### KVKK data rights
- `GET /users/me/export` → full personal-data JSON
- `DELETE /users/me` → 204 (permanent erasure)

### Legal (public HTML)
- `GET /kosullar | /gizlilik | /kvkk`

## Behaviors
- **Quota:** monthly meters share one window. Scans: free 3 / plus 20 / pro ∞.
  Meal plans: free 0 / plus 2 / pro ∞. **Only new-to-catalog AI counts**; cache
  hits are free. Reserved before the Claude call, refunded on failure. Exceed → 402.
- **Trial:** new users get `unlimited_until = now+30d` → effective `pro`.
- **Gating:** trust `GET /users/me/quota` + 402s, NOT the client SubscriptionService.
- **Unicode:** server NFC-normalizes all ingredient names; send clean UTF-8.
  Use `Locale("tr","TR")` for any client-side casing (dotted/dotless I).
- **Friend lookup URL encoding:** percent-encode `+` as `%2B` in `email`/`code` params.
- **Pagination:** only reviews paginate; everything else returns full lists newest-first.
- **Images:** `thumbnail_url` is relative (`/images/<folder>/<file>`) — prepend base URL.
- **Caption fetching** (TikTok/X/Instagram oEmbed + OG/JSON-LD scraping) is
  client-side on iOS (`CaptionService`); reimplement natively on Android. The
  scraped caption/thumbnail feeds `POST /ai/analyze`.

Source of truth: `Feslihan/Services/APIService.swift`, `ClaudeService.swift`,
`feslihan-backend/src/index.ts`, `routes/social.ts`, `quota.ts`, `schema.ts`.
