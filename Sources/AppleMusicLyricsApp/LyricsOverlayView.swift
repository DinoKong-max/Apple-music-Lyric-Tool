import SwiftUI
import AppKit
import AppleMusicLyricsCore

struct LyricsOverlayView: View {
    let currentLine: String
    let nextLine: String
    let preferences: LyricsPreferences
    @State private var isHovered = false

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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(hoverOutline)
        .overlay(HoverTrackingView(isHovered: $isHovered))
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

    @ViewBuilder
    private var hoverOutline: some View {
        if !preferences.isLocked && isHovered {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
        } else {
            Color.clear
        }
    }
}

struct HoverTrackingView: NSViewRepresentable {
    @Binding var isHovered: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isHovered: $isHovered)
    }

    func makeNSView(context: Context) -> TrackingNSView {
        let view = TrackingNSView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: TrackingNSView, context: Context) {
        nsView.coordinator = context.coordinator
    }

    final class Coordinator {
        var isHovered: Binding<Bool>

        init(isHovered: Binding<Bool>) {
            self.isHovered = isHovered
        }

        func setHovered(_ hovered: Bool) {
            isHovered.wrappedValue = hovered
        }
    }
}

final class TrackingNSView: NSView {
    weak var coordinator: HoverTrackingView.Coordinator?
    private var trackingAreaRef: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func mouseEntered(with event: NSEvent) {
        coordinator?.setHovered(true)
    }

    override func mouseExited(with event: NSEvent) {
        coordinator?.setHovered(false)
    }
}

private extension Color {
    init(_ color: CodableColor) {
        self.init(red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
    }
}
