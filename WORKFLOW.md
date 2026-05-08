# SuperAgentIsland 开发工作流

本文是后续 AI / 人工协作开发的入口。目标不是把流程做重，而是让每次改动有清晰边界、验证方式和发布标准。

## 全流程

```text
口头需求
  ↓
[1] 探索澄清
  ↓
[2] 变更说明
  ↓
[3] 行为场景
  ↓
[4] 实现
  ↓
[5] 本地验证
  ↓
[6] 人工验收
  ↓
[7] 发布归档
```

## [1] 探索澄清

适用：需求不够明确，或涉及新页面、新数据源、新账号体系、新发布策略。

要确认：

- 做什么，不做什么。
- 面向谁使用。
- 成功标准是什么。
- 是否影响内置凭据、自动刷新、Sparkle 更新、发布包。

完成标准：能用一句话说清楚“这个改动解决什么问题，以及如何验收”。

## [2] 变更说明

小改动可以直接写在提交信息里；功能性改动建议在 `docs/plans/` 新增设计说明。

建议包含：

- 背景和目标。
- 数据来源或交互入口。
- UI 变更范围。
- 风险点。
- 验证命令。

## [3] 行为场景

对核心功能先写人类可读的 Given / When / Then。当前项目还没有完整 BDD 自动化目录，新增复杂功能时可先在 `docs/plans/` 中写场景。

示例：

```markdown
### 场景：用户查看 GAC 是否今天已重置

Given 应用已配置 GAC 账号
When 后台刷新 tickets 页面
Then 第三面板只展示“今日已重置 / 今日未重置”
```

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
3. 运行 `./scripts/publish-release.sh`。
4. 在 GitHub Release 页面确认 DMG 和 `appcast.xml` 已上传。
5. 安装发布包，确认“立即检查更新”不再报 appcast 缺失。

## 快速判断

| 变更类型 | 流程 |
| --- | --- |
| 文案、间距、颜色小调整 | 直接改 + build + 人工看图 |
| 新增面板字段或布局 | 写变更说明 + build + 验收清单 |
| 新数据源 / 新登录逻辑 | 写设计说明 + 行为场景 + 分层实现 |
| 发布 / 自动更新改动 | 必须跑 release.sh，并检查 appcast |
| 凭据处理改动 | 必须确认真实凭据不入 git |
