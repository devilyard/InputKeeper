# InputKeeper

InputKeeper 是一个 macOS 菜单栏小工具。它会为每个应用记住最后使用的输入法：

- 切换到一个应用时，自动恢复该应用上次使用的输入法。
- 在应用中手动切换输入法时，立即更新该应用的记录。
- 记录保存在本机 `UserDefaults`，退出或重启后仍然有效。
- 不读取键盘内容，不需要“辅助功能”或“输入监控”权限。
- 应用运行在 App Sandbox 中，不上传数据，也不包含分析或广告 SDK。

## 构建与运行

需要 macOS 13 或更高版本以及 Xcode Command Line Tools。

```bash
./Scripts/build-app.sh
open dist/InputKeeper.app
```

启动后，菜单栏会出现键盘图标。第一次切换到某个应用时，InputKeeper 会把当时的输入法作为该应用的初始记录；之后在该应用中手动选择想使用的输入法即可更新记录。

菜单中可以暂停自动切换、查看已记住的应用，或忘记单个应用的记录。若需要开机启动，可在“系统设置 → 通用 → 登录项”中添加 `dist/InputKeeper.app`。

## 开发

可以直接使用 Xcode 打开 `InputKeeper.xcodeproj`，选择 `InputKeeper` Scheme 后点击运行。工程使用 Automatic Signing，Bundle ID 为 `com.typhoon.InputKeeper`。

```bash
swift test
swift run InputKeeper
```

`swift run` 适合开发调试；日常使用建议运行脚本生成的 `.app`。脚本生成的是带 App Sandbox entitlement 的临时签名包，仅供本机测试；提交 Mac App Store 时请使用 Xcode 的 Archive 和 Distribute App 流程。
