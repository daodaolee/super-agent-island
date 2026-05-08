# GAC Credits Design

## Goal

Add a GAC Code Credits page to CodexIsland that fetches the credits balance for two configured accounts without launching a visible browser.

## Constraints

- Use pure HTTP only: `URLSession` login, Bearer token reuse, and JSON parsing.
- Do not bundle Playwright, Chromium, Node.js, or any browser runtime in the first implementation.
- Store account passwords in macOS Keychain, not in source files or committed config.
- Support manual refresh.
- Support a 30-minute auto refresh only after a successful login session exists.
- Re-login only when the saved token is expired or rejected.

## Architecture

- `GACCreditsClient` performs HTTP requests, owns no UI state, and returns parsed credit rows.
- `GACCreditsStore` mirrors the existing `UsageStore`/`CostStore` pattern: `@Published` rows, loading state, last-updated timestamp, manual refresh, timer.
- `GACCredentialsStore` reads and writes Keychain entries for the two fixed account emails.
- `GACCreditsView` becomes a third page in the expanded panel, after Usage and Cost.
- The existing footer refresh action dispatches to the active page's store.

## Data Model

Each account row contains:

- email
- remaining credits
- total credits
- percent
- status or error
- updated timestamp

## HTTP Strategy

1. Submit `POST https://gaccode.com/api/login` with email and password.
2. Store the returned JWT in Keychain and reuse it while its `exp` claim has more than five minutes remaining.
3. Request `GET https://gaccode.com/api/credits/balance` with `Authorization: Bearer <token>`.
4. Parse the returned JSON fields:
   - `balance`
   - `creditCap`
   - `refillRate`
   - `lastRefill`
5. If the token is rejected, clear it and retry by logging in again on the next refresh.

## Packaging

No new runtime is bundled. The app remains a native Swift binary built by `build.sh`, with only source additions under `Sources`.
