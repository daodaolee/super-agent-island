# GAC Credits Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add pure-HTTP GAC Code Credits fetching and display to CodexIsland.

**Architecture:** Add a native Swift client/store/view stack. The client uses `URLSession`, Keychain-stored passwords, Keychain-stored JWTs, and parses the credits JSON API. The store exposes loading, rows, errors, last update, manual refresh, and a 30-minute timer. The view is added as a third page in the existing expanded carousel.

**Tech Stack:** Swift, SwiftUI, Foundation `URLSession`, Security Keychain APIs, existing `build.sh`.

---

### Task 1: Add Credits Model and Parser

**Files:**
- Create: `Sources/Credits/GACCredits.swift`
- Create: `Sources/Credits/GACCreditsParser.swift`

**Steps:**
1. Define `GACCreditAccount`, `GACCreditBalance`, and `GACCreditRow`.
2. Add decodable response structs for `/api/login` and `/api/credits/balance`.
3. Derive percent from `balance / creditCap` only when `creditCap > 0`.
4. Add debug-only self-checks if practical, because this project has no SwiftPM test target.

### Task 2: Add Keychain Credential Store

**Files:**
- Create: `Sources/Credits/GACCredentialsStore.swift`

**Steps:**
1. Add fixed account email list.
2. Read passwords from Keychain service `CodexIsland.GACCredits.password`.
3. Provide save/update methods for Settings UI.
4. Store reusable JWTs in Keychain service `CodexIsland.GACCredits.token`.
5. Never log or expose password values.

### Task 3: Add Pure HTTP Client

**Files:**
- Create: `Sources/Credits/GACCreditsClient.swift`

**Steps:**
1. Reuse a non-expired cached JWT when available.
2. Otherwise submit `POST /api/login`.
3. Fetch `GET /api/credits/balance`.
4. Parse JSON into a native balance model.
5. Return structured account-level errors when login or parsing fails.

### Task 4: Add Credits Store

**Files:**
- Create: `Sources/Credits/GACCreditsStore.swift`
- Modify: `Sources/App.swift`

**Steps:**
1. Mirror `UsageStore` loading/lastUpdated/timer style.
2. Default auto refresh to 30 minutes.
3. Start refresh on app launch.
4. Keep manual refresh guarded by `loading`.

### Task 5: Add Credits UI Page

**Files:**
- Create: `Sources/Views/CreditsView.swift`
- Modify: `Sources/Views/PagedContent.swift`
- Modify: `Sources/Views/PageIndicator.swift`
- Modify: `Sources/Views/PanelFooter.swift`
- Modify: `Sources/Model/ScreenPref.swift`

**Steps:**
1. Add a third carousel page.
2. Render one row per GAC account with remaining, total, percent, and status.
3. Wire footer loading/last-updated/manual refresh to `GACCreditsStore` when the Credits page is active.

### Task 6: Add Settings Credential Inputs

**Files:**
- Modify: `Sources/Views/SettingsView.swift`

**Steps:**
1. Add a Credits section under Providers.
2. Show each fixed email.
3. Provide secure password fields and Save buttons.
4. Do not display stored passwords.

### Task 7: Verify and Package

**Files:**
- Modify as needed: `build.sh` only if native build needs extra framework flags.

**Steps:**
1. Run `./build.sh`.
2. Run `./scripts/verify.sh`.
3. If HTTP login succeeds, launch the app and manually inspect the Credits page.
4. If HTTP login fails due to dynamic login flow, stop and record the exact blocker.
