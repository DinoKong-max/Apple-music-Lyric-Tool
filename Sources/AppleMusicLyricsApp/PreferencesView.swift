import SwiftUI
import AppleMusicLyricsCore

struct PreferencesView: View {
    @State var preferences: LyricsPreferences
    let onSave: (LyricsPreferences) -> Void
    let onResetPosition: () -> Void
    let onClearCache: () -> Void

    var body: some View {
        Form {
            Toggle("显示歌词", isOn: binding(\.isOverlayVisible))
            Toggle("锁定位置", isOn: binding(\.isLocked))

            Picker("字体", selection: binding(\.fontName)) {
                Text("SF Pro Display").tag("SF Pro Display")
                Text("PingFang SC").tag("PingFang SC")
                Text("Helvetica Neue").tag("Helvetica Neue")
                Text("Avenir Next").tag("Avenir Next")
            }

            Slider(value: binding(\.fontSize), in: 18...64, step: 1) {
                Text("字号")
            }
            Slider(value: binding(\.opacity), in: 0.35...1, step: 0.05) {
                Text("透明度")
            }

            Toggle("启用渐变", isOn: binding(\.isGradientEnabled))

            HStack {
                Button("重置位置") {
                    onResetPosition()
                }
                Button("清理缓存") {
                    onClearCache()
                }
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<LyricsPreferences, Value>) -> Binding<Value> {
        Binding(
            get: { preferences[keyPath: keyPath] },
            set: { newValue in
                preferences[keyPath: keyPath] = newValue
                onSave(preferences)
            }
        )
    }
}
