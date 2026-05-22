# Apple Music Lyrics

Apple Music Lyrics 是一个轻量 macOS 菜单栏应用，用于给 Apple Music 当前播放歌曲显示桌面悬浮同步歌词。

## 功能

- Apple Music 当前曲目识别
- LRCLIB 免费同步歌词匹配
- 桌面悬浮歌词窗口
- 锁定后点击穿透
- 字体、字号、颜色、渐变、透明度设置
- 歌词缓存
- `.app` 和 `.dmg` 打包

## 开发

```bash
swift test
swift run AppleMusicLyrics
```

## 打包

```bash
scripts/build_app.sh
scripts/package_dmg.sh
```

## 权限

首次读取 Apple Music 当前播放信息时，macOS 可能会要求授权自动化权限。请允许本应用访问 Music，否则无法识别当前播放歌曲。
