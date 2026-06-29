# Single GAC it-service Account

## 需求

上游 GAC 账号已注销，SuperAgentIsland 只保留 it-service 这一个 GAC 账号。

范围：

- GAC credits 数据源只注入 it-service 账号。
- Credits 面板只展示一个账号块，并保持居中。
- 保持 SuperAgent 账号、刷新间隔、Sparkle 更新逻辑不变。
- 不提交真实账号密码。

## BDD

### 场景：构建时只注入 it-service

Given release secrets 配置了 `GAC_IT_SERVICE_EMAIL` 和 `GAC_IT_SERVICE_PASSWORD`
When 运行 `CLANG_MODULE_CACHE_PATH=/tmp/swift-module-cache ./build.sh`
Then 生成的 `BuildSecrets.gacAccounts` 只包含一个非空账号
And `GACCreditsStore` 只会刷新这一组账号。

### 场景：旧 secrets 平滑迁移

Given 本机仍使用旧的 `GAC_ACCOUNT_1_EMAIL` 和 `GAC_ACCOUNT_1_PASSWORD`
When 没有配置新的 `GAC_IT_SERVICE_EMAIL` 和 `GAC_IT_SERVICE_PASSWORD`
Then 构建脚本回退使用第一组旧变量
And 第二组旧变量不会进入 `BuildSecrets.gacAccounts`。

### 场景：Credits 面板单账号居中

Given `GACCreditsStore.rows` 只有 it-service 一行
When 用户打开第三个 GAC credits 面板
Then 页面只显示一个账号块
And 不显示中间分隔线
And 账号块在面板中居中。

## 验证计划

- 运行 `CLANG_MODULE_CACHE_PATH=/tmp/swift-module-cache ./build.sh`。
- 构建后只检查生成源码里的账号 tuple 数量，不输出 secret 值。
- 人工打开 App 第三页，确认只显示一个 GAC 账号块且居中。
- 发布前按 `acceptance/checklist.md` 重新验收。
