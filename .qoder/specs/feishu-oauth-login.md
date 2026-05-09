# 飞书 OAuth 登录 + 移除硬编码凭据

## Context

当前 SuperAgentIsland 的账号体系仅支持用户名密码登录（通过 Casdoor OAuth2 流程），且默认凭据从构建时注入（BuildSecrets），导致开发者的账号密码被写死在构建脚本中。用户要求：

1. 新增飞书第三方授权登录作为替代登录方式
2. 移除默认硬编码的账号密码，改为用户首次使用时手动输入，并持久化
3. 飞书 logo 使用用户提供的 SVG（转为 PNG 资源）

Casdoor 已配置飞书 provider：`provider_feishu_qa`（type: Lark, clientId: `cli_a90149cf6979dcba`），Casdoor 登录页面原生支持飞书登录按钮。

---

## 实现方案

### 整体架构

```
Settings 账号 Tab
├── 登录方式选择器: [密码登录 | 飞书登录]
├── 未登录: 选择密码登录或飞书登录（二选一）
├── 密码模式: email + password 输入框 + 登录按钮
├── 飞书模式: 飞书登录按钮
└── 已登录: 锁定登录方式，只显示授权状态、刷新和退出登录

SuperAgentCredentialsStore (重构)
├── authMethod: .password | .feishu
├── email/password → UserDefaults 持久化
├── session cookies → UserDefaults 持久化 (两种模式共用)
└── 启动时: 从 UserDefaults 恢复 cookies → HTTPCookieStorage

飞书登录流程:
  点击按钮 → 打开 WKWebView 窗口 → 加载 Casdoor 登录页 →
  用户点飞书图标 → 飞书授权 → 回调到 SuperAgent →
  提取 cookies → 注入 HTTPCookieStorage → 关闭窗口
```

---

### 文件变动清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `Sources/SuperAgent/SuperAgentCredentialsStore.swift` | 重构 | authMethod enum、UserDefaults 持久化、cookie 存储/恢复 |
| `Sources/SuperAgent/FeishuLoginWindowController.swift` | 新建 | WKWebView OAuth 窗口 |
| `Sources/SuperAgent/SuperAgentClient.swift` | 修改 | 新增 session-only 模式、sessionExpired 错误 |
| `Sources/SuperAgent/SuperAgentUsageStore.swift` | 修改 | 双模式 refresh 逻辑 |
| `Sources/Views/SettingsView.swift` | 修改 | 登录方式切换 UI、飞书按钮 |
| `Resources/feishu_logo.png` | 新建 | 飞书 Logo（从 SVG 转换） |
| `build.sh` | 修改 | 添加 WebKit framework、feishu_logo 资源拷贝、SA 凭据置空 |
| `.release-secrets.env.example` | 修改 | 移除 SUPERAGENT 相关行 |

---

### 1. SuperAgentCredentialsStore 重构

```swift
enum SuperAgentAuthMethod: String {
    case password
    case feishu
}

@MainActor
final class SuperAgentCredentialsStore: ObservableObject {
    static let shared = SuperAgentCredentialsStore()

    @Published var authMethod: SuperAgentAuthMethod  // UserDefaults 持久化
    @Published var email: String                     // UserDefaults 持久化
    @Published var password: String                  // UserDefaults 持久化
    @Published var lastError: String?

    // 初始化: UserDefaults → BuildSecrets fallback → 空
    // isConfigured: password 模式检查 email+password; feishu 模式检查 stored cookies
    // saveCookies: 将 cookies.properties 序列化为 Data 存入 UserDefaults
    // restoreCookies: 从 UserDefaults 反序列化注入 HTTPCookieStorage
    // clearSession: 清除 HTTPCookieStorage + UserDefaults cookies
}
```

**持久化策略：**
- email → `UserDefaults["SuperAgent.email"]`
- password → `UserDefaults["SuperAgent.password"]`（内部工具可接受）
- authMethod → `UserDefaults["SuperAgent.authMethod"]`
- cookies → `UserDefaults["SuperAgent.sessionCookies"]`（PropertyList 序列化 cookie properties 数组）

**迁移逻辑：** 首次启动时若 UserDefaults 无值但 BuildSecrets 非空，则从 BuildSecrets 迁移一次。

---

### 2. FeishuLoginWindowController（新建）

```swift
import AppKit
import WebKit

@MainActor
final class FeishuLoginWindowController: NSWindowController, WKNavigationDelegate {
    // 创建 600x650 窗口，内含 WKWebView
    // 加载 URL: https://superagentai-qa.fireflyfusion.cn/api/v1/auth/login
    //   → 302 跳转到 Casdoor 登录页（含飞书按钮）
    //   → 用户点飞书 → 飞书授权 → 回调
    //
    // Navigation delegate 监听:
    //   当 URL domain 回到 superagentai-qa.fireflyfusion.cn 且路径非 /api/v1/auth/login 时
    //   → didFinish 中提取 cookies:
    //     webView.configuration.websiteDataStore.httpCookieStore.getAllCookies
    //   → 过滤 superagentai-qa.fireflyfusion.cn domain
    //   → 注入 HTTPCookieStorage.shared
    //   → 通过 completion handler 通知成功
    //   → 关闭窗口
    
    var onComplete: (([HTTPCookie]) -> Void)?
    var onCancel: (() -> Void)?
}
```

**关键点：** Cookie 提取必须在 `webView(_:didFinish:)` 中执行（此时 Set-Cookie 响应头已处理），不能在 `decidePolicyFor` 中提取。

---

### 3. SuperAgentClient 修改

新增方法和错误类型：

```swift
case sessionExpired  // "登录已过期，请重新登录。"

// 仅使用已有 cookies 请求数据，不做 password login
func fetchDashboardWithSession(range: SuperAgentUsageRange) async throws 
    -> (SuperAgentDashboardSnapshot, SuperAgentUser?) {
    guard try await isAuthenticated() else {
        throw SuperAgentClientError.sessionExpired
    }
    return try await requestDashboard(range: range)
}
```

---

### 4. SuperAgentUsageStore 修改

`refresh()` 根据 authMethod 分流：

```swift
func refresh() {
    // ...
    let method = credentials.authMethod
    refreshTask = Task.detached(priority: .utility) {
        do {
            let client = SuperAgentClient()
            let result: (SuperAgentDashboardSnapshot, SuperAgentUser?)
            switch method {
            case .password:
                result = try await client.fetchDashboard(email: email, password: password, range: activeRange)
            case .feishu:
                result = try await client.fetchDashboardWithSession(range: activeRange)
            }
            // ... update state, persist cookies
        } catch {
            // sessionExpired 时设置友好错误提示
        }
    }
}
```

---

### 5. SettingsView UI 变更

账号 Tab 布局改为：

```
┌─ SUPERAGENT ─────────────────────────────────────────────┐
│ ● Web 登录                                    [已配置]    │
│   <状态文本>                                              │
│                                                          │
│   [密码登录 | 飞书登录]  ← 未登录时显示                   │
│                                                          │
│   ── 密码登录选中时 ──                                    │
│   [___账号___] [___密码___] [登录]                        │
│                                                          │
│   ── 飞书登录选中时 ──                                    │
│   [飞书Logo 飞书登录按钮]                                  │
│                                                          │
├──────────────────────────────────────────────────────────┤
│ 已登录后                                                  │
│                         [密码登录/飞书登录] [退出登录]     │
│                         [刷新]                            │
└──────────────────────────────────────────────────────────┘
```

飞书登录按钮：使用 `feishu_logo.png` 作为左侧图标，背景 `#3370FF` opacity(0.15)，圆角 8px。

---

### 6. build.sh 修改

1. `BuildSecrets.swift` 模板中 `superAgentUsername` / `superAgentPassword` 固定为 `""`（保持编译兼容）
2. 新增：`cp ./Resources/feishu_logo.png "$RES_DIR/feishu_logo.png"`
3. swiftc 新增：`-framework WebKit`
4. 移除从 env 读取 `SUPERAGENT_USERNAME` / `SUPERAGENT_PASSWORD` 的逻辑

---

### 7. Session 过期处理

| 方式 | 过期后行为 |
|------|-----------|
| 密码 | 自动用存储的 email+password 重新 login（现有逻辑） |
| 飞书 | 显示错误 "飞书登录已过期，请在设置中重新登录"，需用户手动操作 |

---

## 验证计划

1. **编译验证：** `CLANG_MODULE_CACHE_PATH=/tmp/swift-module-cache ./build.sh`
2. **密码登录流程：**
   - 打开设置 → 账号 Tab → 选择"密码登录"
   - 输入账号密码 → 点"登录"→ 验证通过
   - 关闭并重新打开 app → 凭据已保存，自动刷新成功
3. **飞书登录流程：**
   - 切换到"飞书登录"→ 点击飞书登录按钮
   - WebView 窗口打开 → 显示 Casdoor 页面（含飞书图标）
   - 点飞书完成授权 → 窗口自动关闭
   - 设置页显示"已登录"状态
   - 点"刷新"→ 数据正常获取
   - 重启 app → session 保持，自动刷新成功
4. **退出登录：** 点击退出登录 → 清除 session → 状态回到未登录
5. **向后兼容：** 旧 BuildSecrets 用户升级后，首次启动自动迁移凭据到 UserDefaults
