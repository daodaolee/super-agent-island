# SuperAgentIsland 开发工作流

本文是后续 AI / 人工协作开发的入口。目标不是把流程做重，而是让每次改动有清晰边界、验证方式和发布标准。

## 硬约束

从 `0.0.2` 发布后，所有非平凡需求必须按下面顺序推进：

```text
需求 -> BDD -> TDD / 验证计划 -> 实现 -> 验收 -> 发布归档
```

执行规则：

- 不清楚目标时，先澄清需求，不直接写代码。
- 涉及功能、数据口径、交互、发布、凭据、自动刷新、更新机制的改动，先写 BDD 场景。
- 能自动化测试的行为，先写失败用例，再实现；SwiftUI 视觉类改动至少要写清楚人工验收步骤。
- 没有验收证据，不声明完成。
- 发布后必须新增或更新 `docs/releases/` 下的归档。

## 全流程

```text
需求输入
  ↓
[1] 需求澄清
  ↓
[2] BDD 场景
  ↓
[3] TDD / 验证计划
  ↓
[4] 实现
  ↓
[5] 本地验证
  ↓
[6] 人工验收
  ↓
[7] 发布归档
```

## [1] 需求澄清

适用：需求不够明确，或涉及新页面、新数据源、新账号体系、新发布策略。

要确认：

- 做什么，不做什么。
- 面向谁使用。
- 成功标准是什么。
- 是否影响内置凭据、自动刷新、Sparkle 更新、发布包。

完成标准：能用一句话说清楚“这个改动解决什么问题，以及如何验收”。

## [2] BDD 场景

对核心功能先写人类可读的 Given / When / Then。当前项目还没有完整 BDD 自动化目录，新增复杂功能时可先在 `docs/plans/` 中写场景。

场景必须覆盖：

- 正常路径。
- 空数据 / loading / 请求失败。
- 时间范围或自动刷新类边界。
- 设置项和内置凭据类边界。

示例：

```markdown
### 场景：用户查看 GAC 是否今天已重置

Given 应用已配置 GAC 账号
When 后台刷新 tickets 页面
Then 第三面板只展示“今日已重置 / 今日未重置”
```

## [3] TDD / 验证计划

小改动可以直接写在提交信息里；功能性改动建议在 `docs/plans/` 新增设计说明。

建议包含：

- 背景和目标。
- 数据来源或交互入口。
- UI 变更范围。
- 风险点。
- 自动化测试或人工验收步骤。
- 验证命令。

能自动化的逻辑优先补测试；当前 Swift 项目若暂时没有对应测试 harness，也必须写清楚最小可重复验证方式。

## [4] 实现

原则：

- **模块优先**：数据抓取、解析、状态存储、UI 展示分层处理。
- **副作用在边界**：网络、cookie、token、计时器集中在 Store / Client。
- **不提交真实凭据**：真实账号密码只在本地 release secrets 中。
- **尊重现有视觉约束**：岛屿缩小态不承载过多文字；展开态不溢出、不遮挡。

## [5] 本地验证

每次提交前至少运行：

```bash
CLANG_MODULE_CACHE_PATH=/tmp/swift-module-cache ./build.sh
```

发布前运行：

```bash
CLANG_MODULE_CACHE_PATH=/tmp/swift-module-cache ./release.sh
```

如果改动涉及启动流程，可运行：

```bash
./scripts/verify.sh
```

## [6] 人工验收

按 [acceptance/checklist.md](acceptance/checklist.md) 验证。UI 改动必须实际打开 App 看：

- 缩小态。
- hover 态。
- 展开态三面板。
- 设置窗口。
- Release 后的更新检查。

## [7] 发布归档

发布流程：

1. 更新 `VERSION`。
2. 更新 `CHANGELOG.md`。
3. 运行 `CLANG_MODULE_CACHE_PATH=/tmp/swift-module-cache ./scripts/publish-release.sh`。
4. 在 GitHub Release 页面确认 DMG 和 `appcast.xml` 已上传。
5. 安装发布包，确认“立即检查更新”不再报 appcast 缺失。
6. 在 `docs/releases/` 新增版本归档，记录 Release URL、核心变更、验证命令和资产摘要。

## 快速判断

| 变更类型 | 流程 |
| --- | --- |
| 文案、间距、颜色小调整 | 直接改 + build + 人工看图 |
| 新增面板字段或布局 | 需求澄清 + BDD + 验证计划 + build + 验收清单 |
| 新数据源 / 新登录逻辑 | 需求澄清 + BDD + TDD / 验证计划 + 分层实现 |
| 发布 / 自动更新改动 | 必须跑 publish-release.sh，并检查 Release 与 appcast |
| 凭据处理改动 | 必须确认真实凭据不入 git |
