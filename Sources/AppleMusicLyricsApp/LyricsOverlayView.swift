import SwiftUI
import AppleMusicLyricsCore

struct LyricsOverlayView: View {
    let currentLine: String
    let nextLine: String
    let preferences: LyricsPreferences

    var body: some View {
        VStack(spacing: 10) {
            lyricText(currentLine, size: preferences.fontSize, opacity: preferences.opacity)
                .fontWeight(.bold)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Text(nextLine)
                .font(.custom(preferences.fontName, size: max(preferences.fontSize * 0.52, 14)))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
        .shadow(color: .black.opacity(0.45), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .background(Color.clear)
    }

    @ViewBuilder
    private func lyricText(_ text: String, size: Double, opacity: Double) -> some View {
        let font = Font.custom(preferences.fontName, size: size)
        if preferences.isGradientEnabled {
            Text(text)
                .font(font)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(preferences.gradientStartColor),
                            Color(preferences.gradientEndColor)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .opacity(opacity)
                )
        } else {
            Text(text)
                .font(font)
                .foregroundStyle(Color(preferences.primaryColor).opacity(opacity))
        }
    }
}

private extension Color {
    init(_ color: CodableColor) {
        self.init(red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
    }
}
