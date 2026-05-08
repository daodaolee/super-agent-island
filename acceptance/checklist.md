# SuperAgentIsland 验收清单

每次发布前按顺序执行。遇到失败项，应记录原因并修复后重新验收。

## 1. 构建与打包

```bash
CLANG_MODULE_CACHE_PATH=/tmp/swift-module-cache ./build.sh
```

- [ ] 生成 `build/SuperAgentIsland.app`。
- [ ] 构建过程无 Swift 编译错误。

```bash
CLANG_MODULE_CACHE_PATH=/tmp/swift-module-cache ./release.sh
```

- [ ] 生成 `dist/SuperAgentIsland-<version>.dmg`。
- [ ] 生成 `dist/appcast.xml`。
- [ ] `appcast.xml` 中的 DMG URL、版本号、签名字段存在。

## 2. 启动与基础交互

- [ ] App 可以启动，不崩溃。
- [ ] 缩小态只显示两个百分比圆环。
- [ ] hover 后岛屿变宽，显示 logo 和 `额度` / `积分` 提示。
- [ ] 点击后展开完整面板。
- [ ] 鼠标移出后能正常收回。

## 3. 用量概览面板

- [ ] 显示 SuperAgent 总额度、剩余额度、下次重置时间。
- [ ] 显示调用次数、预估费用、结算费用。
- [ ] 显示输入 / 输出 Token 图形。
- [ ] 显示用量趋势图。
- [ ] 长文本在今日、近 7 天、近 30 天、全部范围下不溢出。

## 4. 模型排行面板

- [ ] 按当前时间范围展示前 4 个高用量模型。
- [ ] 模型名称完整可读，不被省略到无法识别。
- [ ] 输入 / 输出 Token 柱状图数字完整展示。
- [ ] 调用次数和预估费用数字完整展示。
- [ ] `Command` + 点击可以切换时间范围。

## 5. GAC 积分面板

- [ ] 两个账号都能展示剩余 / 总量。
- [ ] 只展示今天是否已重置，不展示工单详情。
- [ ] 页面加载慢时有合理 loading 状态。
- [ ] token 复用正常，不因手动刷新每次都重新登录。

## 6. 设置窗口

- [ ] 通用：开机自启动、刷新间隔、自动检查更新、立即检查可见。
- [ ] 刷新间隔切换后，SuperAgent 和 GAC 自动刷新频率一致更新。
- [ ] 显示：低功耗模式可切换。
- [ ] 账号：SuperAgent Web 账号密码可输入。
- [ ] 账号测试按钮能反馈成功或失败。
- [ ] 设置窗口中文文案完整，不出现旧 CodexIsland 文案。

## 7. 更新与发布

- [ ] `gh auth status` 已登录。
- [ ] `./scripts/publish-release.sh` 能完成发布。
- [ ] GitHub Release 包含 DMG 和 `appcast.xml`。
- [ ] 安装发布包后，“立即检查更新”不会出现 appcast 404。

## 8. 安全检查

```bash
git grep -n "Qq6M2RxBx8bq\|Rge0BbBATUuh\|it-service1@quvideo.com\|it-service@quvideo.com" -- . ':!*.example'
```

- [ ] git 跟踪内容里没有真实密码。
- [ ] 真实凭据只存在于 `~/.super-agent-island/release-secrets.env`。
- [ ] Sparkle 私钥只存在于 `~/.super-agent-island/sparkle-private-key` 或安全的 CI secret。

## 9. Definition of Done

- [ ] 构建通过。
- [ ] Release 打包通过。
- [ ] 核心交互人工验收通过。
- [ ] 无已知 P0/P1 bug。
- [ ] README / CHANGELOG / PROJECT_OVERVIEW 与实际行为一致。
- [ ] 发布包和 appcast 已上传到 GitHub Release。
