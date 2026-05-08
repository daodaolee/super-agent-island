# SuperAgent Panel Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the original Claude/Codex OAuth usage panel with SuperAgent quota and usage data, while keeping GAC credits as a fixed stepped chart.

**Architecture:** Add a native Swift `URLSession` client for the SuperAgent/Casdoor SSO flow and SuperAgent usage APIs. Store the SuperAgent email in `UserDefaults`, password and session cookies in Keychain, and expose a main-actor observable store for SwiftUI. Reuse the existing island layout, footer refresh affordance, and chart vocabulary.

**Tech Stack:** Swift, SwiftUI, URLSession, Security Keychain, CommonCrypto AES-CBC for Casdoor password obfuscation.

---

### Task 1: SuperAgent Data Layer

**Files:**
- Create: `Sources/SuperAgent/SuperAgentUsage.swift`
- Create: `Sources/SuperAgent/SuperAgentCredentialsStore.swift`
- Create: `Sources/SuperAgent/SuperAgentClient.swift`
- Create: `Sources/SuperAgent/SuperAgentUsageStore.swift`

**Steps:**
1. Define quota, summary, range, and dashboard snapshot models.
2. Implement Settings-backed email plus Keychain-backed password/cookies.
3. Implement Casdoor SSO login: start SuperAgent auth, fetch Casdoor app metadata, AES-obfuscate password, request OAuth code, complete SuperAgent callback.
4. Implement API reads for `/quotas/summary`, `/usage/summary`, and `/usage/trend`.
5. Add a store with manual refresh, 30-minute timer, and Command-click range cycling.

### Task 2: First Panel UI

**Files:**
- Modify: `Sources/Views/UsageView.swift`
- Modify: `Sources/Views/PanelHeader.swift`
- Modify: `Sources/Views/PanelFooter.swift`
- Modify: `Sources/Views/IslandRootView.swift`
- Modify: `Sources/App.swift`

**Steps:**
1. Render SuperAgent quota on the left and usage overview on the right.
2. Replace usage page Command-click behavior with today/7d/30d cycling.
3. Point footer loading/freshness/refresh to the SuperAgent store on the first page.
4. Start SuperAgent auto-refresh at launch.

### Task 3: Settings and GAC Polish

**Files:**
- Modify: `Sources/Views/SettingsView.swift`
- Modify: `Sources/Views/CreditsView.swift`

**Steps:**
1. Add compact SuperAgent account rows to Settings.
2. Fix GAC charts to stepped style only.
3. Increase GAC chart visual size and center it vertically with the right-side text.

### Task 4: Verification

**Commands:**
- `./scripts/verify.sh`
- `./release.sh`

**Expected:** Both commands complete successfully and produce a fresh macOS app/DMG.
