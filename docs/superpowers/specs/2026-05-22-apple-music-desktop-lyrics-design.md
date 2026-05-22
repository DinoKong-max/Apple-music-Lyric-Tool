# Apple Music 桌面歌词插件设计规格 / Desktop Lyrics Design Spec

## 1. 目标 / Goal

做一个轻量的 macOS 菜单栏应用，为 Apple Music 当前播放歌曲提供桌面悬浮同步歌词。第一版要先把核心体验打通：启动快、占用低、能自动识别当前歌曲、能匹配免费在线歌词、能显示可锁定/可拖动的桌面歌词，并提供基本设置。

Build a lightweight macOS menu bar app that shows synced desktop lyrics for the currently playing Apple Music track. The first shippable version focuses on fast startup, low resource use, reliable track detection, free online lyrics matching, lockable/draggable floating lyrics, and basic preferences.

## 2. MVP 范围 / MVP Scope

必须实现：

- 识别 Apple Music 当前曲目：歌名、歌手、专辑、时长、播放状态、播放进度。
- 使用免费在线歌词源匹配同步歌词，第一优先级为 LRCLIB。
- 显示桌面悬浮歌词窗口，包含当前歌词和下一句歌词。
- 支持两种窗口模式：
  - 未锁定：窗口悬浮在普通窗口之上，可拖动位置。
  - 已锁定：窗口不可拖动，并且鼠标点击穿透，不影响操作后面的应用。
- 状态栏图标菜单：显示/隐藏歌词、锁定/解锁、刷新歌词、偏好设置、关于、退出。
- 偏好设置：字体、字号、歌词颜色、渐变色、透明度、重置位置、清理缓存。
- 本地缓存已匹配歌词，减少网络请求并提升再次播放时的速度。
- 能打包为带版本号的 `.app`，并进一步生成可分享的 `.dmg`。

Must have:

- Detect current Apple Music metadata and playback position.
- Fetch synced lyrics from a free online source, starting with LRCLIB.
- Render current and next lyric lines in a floating desktop window.
- Support unlocked drag mode and locked click-through mode.
- Provide a menu bar icon with common controls.
- Persist visual preferences and cache matched lyrics.
- Build a versioned `.app` and package a distributable `.dmg`.

暂不做：

- 逐字卡拉 OK 效果。LRCLIB 通常提供逐行 LRC，不保证逐字。
- 付费歌词 API。
- App Store 发布。
- 跨平台版本。
- 依赖 Apple Music 私有接口读取官方歌词。

Out of MVP:

- Word-by-word karaoke timing.
- Paid lyrics providers.
- App Store distribution.
- Cross-platform support.
- Private Apple Music lyrics endpoints.

## 3. 技术路线 / Technical Approach

推荐使用 Swift 6 + AppKit + SwiftUI 做原生 macOS 应用。

- `NSStatusItem`：状态栏图标和菜单。
- `NSPanel` 或无边框 `NSWindow`：桌面悬浮歌词窗。
- `UserDefaults`：保存用户偏好。
- `Application Support` 本地文件：保存歌词缓存。
- `URLSession`：请求 LRCLIB API。
- Swift Package Manager：先建立轻量工程，再补打包脚本。

This native stack is smaller and more macOS-friendly than Electron. It maps directly to menu bar apps, click-through windows, system fonts, color pickers, and permission messaging.

## 4. 播放识别 / Track Detection

采用“两层识别”：

1. AppleScript 轮询，约每 0.5-1 秒读取 Apple Music：
   - 播放状态
   - 当前播放进度
   - 歌名
   - 歌手
   - 专辑
   - 时长
   - 可用时读取 persistent ID

2. 监听 Apple Music 播放状态通知，用于更快响应切歌/暂停/播放变化。通知负载不保证长期稳定，所以轮询仍作为真实来源。

权限预期：

- macOS 可能要求用户授权“自动化”，允许本应用控制或读取 Music。
- 如果某些机器需要额外辅助功能权限，应用要在设置页展示修复说明，不能静默失败。

失败处理：

- Music 未运行：状态栏显示“Apple Music 未运行”，默认隐藏悬浮窗。
- 暂停播放：停在当前歌词，不继续推进。
- 元数据不完整：用已有字段搜索并降低匹配置信度。
- AppleScript 被拒绝：状态栏显示警告，设置页提示如何重新授权。

The detector reads Music through AppleScript polling and uses distributed notifications as a fast hint. Polling remains the source of truth because notification payloads may change.

## 5. 歌词来源策略 / Lyrics Source Strategy

第一免费来源：LRCLIB。

- 使用 `/api/search`，传入 `track_name`、`artist_name`、`album_name` 和时长。
- 优先选择带 `syncedLyrics` 的结果。
- 按标题/歌手精确度、时长接近度、专辑匹配度、有无同步歌词进行排序。
- 用“歌名 + 歌手 + 专辑 + 四舍五入时长”生成缓存 key。

兜底顺序：

1. 本地缓存歌词。
2. 用户手动导入 `.lrc`。
3. 没有同步歌词时显示纯文本歌词。
4. 免费方案效果不够时，再询问是否接入付费 API。

Apple Music 官方 API 不作为 MVP 依赖。Apple MusicKit 官方说明主要覆盖曲库、播放、推荐、用户音乐数据等能力，没有把歌词读取作为这个桌面悬浮歌词场景的稳定公开接口。

Primary source: LRCLIB. Fallbacks are cache, imported LRC, plain lyrics, and then optional paid API discussion.

参考 / References:

- LRCLIB: https://lrclib.net
- Apple MusicKit: https://developer.apple.com/musickit/

## 6. 歌词同步模型 / Lyrics Sync Model

LRC 解析成时间戳行：

```swift
struct LyricLine: Equatable {
    let time: TimeInterval
    let text: String
}
```

每次播放 tick：

- 从播放器识别器读取播放进度。
- 用二分查找找到当前行。
- 输出当前歌词、下一句歌词和行内进度。
- 内部支持时间偏移，默认 `0.0` 秒；如果真实歌曲经常漂移，后续再开放 UI 调整。

At each playback tick, the synchronizer maps playback position to current and next lyric lines.

## 7. 界面设计 / UI Design

### 7.1 桌面悬浮歌词窗 / Floating Lyrics Window

视觉方向：

- 无边框透明窗口。
- 当前歌词大号居中显示。
- 下一句歌词小号显示在下方。
- 可选轻微文字阴影，增强桌面背景上的可读性。
- 支持纯色歌词和两到三色渐变歌词。
- 不做厚重窗口边框、卡片背景和装饰性背景。

交互模式：

- 未锁定：
  - 浮在普通窗口之上。
  - 可用鼠标拖动。
  - 悬停时显示可移动状态。

- 已锁定：
  - 设置 `ignoresMouseEvents = true`。
  - 保持可见，但不可拖动。
  - 点击穿透到后面的应用。

### 7.2 状态栏菜单 / Menu Bar

菜单项：

- 显示/隐藏歌词
- 锁定/解锁位置
- 刷新歌词
- 偏好设置...
- 关于
- 退出

状态图标：

- 使用类似 SF Symbols 的音乐/歌词图标。
- 权限或歌词匹配失败时显示警告状态。

### 7.3 偏好设置 / Preferences

使用简洁的 SwiftUI 原生窗口：

- 歌词开关
- 锁定开关
- 字体选择
- 当前歌词颜色
- 渐变开关
- 渐变起止颜色
- 字号滑块
- 透明度滑块
- 重置位置
- 清理缓存

整体风格遵循苹果产品的克制、清晰、轻量：原生控件、舒适间距、少装饰。

## 8. 架构模块 / Architecture

- `AppCoordinator`：应用生命周期，启动服务，连接菜单和窗口。
- `MusicTrackDetector`：读取 Apple Music 状态，输出 `TrackSnapshot`。
- `LyricsProvider`：歌词源协议。
- `LRCLIBLyricsProvider`：LRCLIB 免费歌词实现。
- `LyricsCache`：歌词缓存读写。
- `LRCParser`：解析 LRC 文本。
- `LyricsSynchronizer`：根据播放进度计算当前/下一句歌词。
- `LyricsOverlayController`：管理悬浮窗、锁定、拖动、点击穿透。
- `PreferencesStore`：保存用户设置。
- `StatusMenuController`：构建状态栏菜单。

Core models:

```swift
struct TrackSnapshot: Equatable {
    let title: String
    let artist: String
    let album: String?
    let duration: TimeInterval?
    let position: TimeInterval
    let isPlaying: Bool
    let persistentID: String?
}

struct LyricsResult: Equatable {
    let source: LyricsSource
    let syncedLines: [LyricLine]
    let plainText: String?
    let confidence: Double
}

enum LyricsSource: String, Codable {
    case lrclib
    case localCache
    case importedLRC
}
```

## 9. 打包与版本 / Packaging And Versioning

- 使用 SemVer，从 `0.1.0` 开始。
- 版本号只维护一处，再同步到 bundle metadata 和 release 脚本。
- 第一阶段先能构建 `.app`。
- 第二阶段生成 `.dmg`，方便分享。
- Sparkle 自动更新、签名、公证作为 MVP 后增强，因为需要 Apple Developer 账号和发布策略。

Use SemVer, build `.app` first, then package `.dmg`. Notarization and auto-update are post-MVP.

## 10. 测试策略 / Testing Strategy

自动化测试：

- LRC 解析：多时间戳格式、空行、重复时间戳。
- LRCLIB 排序：歌名/歌手/专辑/时长匹配权重。
- 歌词同步：时间边界前后当前行是否正确。
- 缓存：key 生成、读写、损坏缓存处理。

手动测试：

- Apple Music 权限授权流程。
- 播放、暂停、切歌、拖动进度条。
- 悬浮窗锁定后是否点击穿透。
- 字体、颜色、渐变、透明度是否持久化。
- `.app` 和 `.dmg` 能否在本机运行。

Automated tests cover parser, ranking, synchronization, and cache. Manual tests cover macOS permissions and window behavior.

## 11. 风险与应对 / Risks And Mitigations

- AppleScript 权限可能被拒绝。
  - 应对：状态栏显示警告，设置页给出修复步骤。

- 免费歌词匹配可能不准。
  - 应对：时长感知排序、本地缓存、刷新按钮、手动导入 LRC。

- Apple Music 官方歌词不可稳定读取。
  - 应对：MVP 不依赖私有 API；免费源效果不足再讨论付费 API。

- 当前环境没有完整 Xcode。
  - 应对：先用 SwiftPM 建轻量工程和核心测试；发布打包步骤单独脚本化。

## 12. 验收标准 / Acceptance Criteria

- 启动应用后只出现状态栏图标，不出现 Dock 图标。
- Apple Music 播放歌曲时，约 1 秒内识别曲目信息和播放进度。
- 成功匹配 LRCLIB 同步歌词后，悬浮窗显示当前歌词。
- 播放时歌词推进，暂停时歌词停止推进。
- 状态栏菜单可执行显示/隐藏、锁定/解锁、刷新歌词、打开偏好设置、退出。
- 锁定后的悬浮歌词窗不拦截鼠标点击。
- 字体、颜色、渐变、透明度等设置重启后仍保留。
- 能构建带版本号的 `.app`，并能生成用于分享的 `.dmg`。

