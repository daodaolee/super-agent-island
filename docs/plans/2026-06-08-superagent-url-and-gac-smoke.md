# SuperAgent URL and GAC Credits Smoke

## Requirement

Update the SuperAgent personal usage entry from the QA site to:

```text
https://superagentai.fireflyops.cn/dashboard
```

Keep GAC credits fetching unchanged unless live smoke proves the existing
credits balance path is no longer usable.

## BDD

### Scenario: SuperAgent dashboard uses the production FireflyOps host

Given the app needs to fetch personal SuperAgent usage
When it starts a login or API refresh
Then the dashboard entry is `https://superagentai.fireflyops.cn/dashboard`
And the API base is `https://superagentai.fireflyops.cn`
And the auth host accepted by the login flow is `auth.superagentai.fireflyops.cn`

### Scenario: GAC daily balance remains readable

Given the app has embedded GAC credentials from local release secrets
When it logs in to `https://gaccode.com`
Then `GET /api/credits/balance` returns HTTP 200 with a numeric balance
And `GET /api/tickets?page=1&limit=20` returns HTTP 200 so today's reset
ticket can still be detected.

## Verification Plan

- Endpoint unit smoke:

```bash
swiftc Sources/SuperAgent/SuperAgentEndpoints.swift Tests/main.swift -o /tmp/superagent-endpoint-tests && /tmp/superagent-endpoint-tests
```

- GAC live smoke using local secrets, with credentials and tokens redacted.
- Full app build:

```bash
CLANG_MODULE_CACHE_PATH=/tmp/swift-module-cache ./build.sh
```

## Verification Evidence

Collected on 2026-06-08 with credentials and tokens redacted.

- Endpoint test passed:

```text
superagent endpoint tests passed
```

- SuperAgent live smoke:

```text
dashboard_http=200
login_http_redirect=302 https://auth.superagentai.fireflyops.cn/login/oauth/authorize?...
/api/v1/auth/me=401
/api/v1/usage/summary=401
/api/v1/quotas/summary=401
```

- GAC live smoke:

```text
account_1 login=ok credits_balance_http=200 balance=34685 creditCap=0 refillRate=0 tickets_http=200 today_reset_tickets=0
account_2 login=ok credits_balance_http=200 balance=87651 creditCap=100000 refillRate=5000 tickets_http=200 today_reset_tickets=1
```

- Full app build passed:

```text
✓ built ./build/SuperAgentIsland.app (0.0.4)
```
