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
                .lineLimit(1)
                .minimumScaleFactor(0.62)
            Text(nextLine)
                .font(.custom(preferences.fontName, size: max(preferences.fontSize * 0.52, 14)))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .multilineTextAlignment(.center)
        .shadow(color: .black.opacity(0.45), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(selectionOutline)
        .overlay(alignment: .bottomTrailing) {
            resizeHint
        }
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
    private var selectionOutline: some View {
        if !preferences.isLocked {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(isHovered ? 0.08 : 0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(isHovered ? 0.65 : 0.28), lineWidth: isHovered ? 1.4 : 1)
                )
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var resizeHint: some View {
        if !preferences.isLocked {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(isHovered ? 0.85 : 0.55))
                .padding(.trailing, 8)
                .padding(.bottom, 7)
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
