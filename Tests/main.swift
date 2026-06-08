import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

expect(
    SuperAgentEndpoints.dashboardURL.absoluteString == "https://superagentai.fireflyops.cn/dashboard",
    "dashboard URL should point to production FireflyOps dashboard"
)
expect(
    SuperAgentEndpoints.apiBase.absoluteString == "https://superagentai.fireflyops.cn",
    "API base should use production FireflyOps host"
)
expect(
    SuperAgentEndpoints.authBase.absoluteString == "https://auth.superagentai.fireflyops.cn",
    "auth base should use production auth host"
)
expect(
    SuperAgentEndpoints.loginStartURL.absoluteString == "https://superagentai.fireflyops.cn/api/v1/auth/login",
    "login start URL should use the production API login path"
)
expect(
    SuperAgentEndpoints.isAcceptedAuthHost("auth.superagentai.fireflyops.cn"),
    "production auth host should be accepted"
)
expect(
    !SuperAgentEndpoints.isAcceptedAuthHost("casdoor-qa.fireflyfusion.cn"),
    "QA auth host should not be accepted"
)

print("superagent endpoint tests passed")
