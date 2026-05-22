import Foundation
import AppleMusicLyricsCore

@MainActor
final class LyricsOverlayModel: ObservableObject {
    @Published var currentLine: String
    @Published var nextLine: String
    @Published var preferences: LyricsPreferences

    init(currentLine: String, nextLine: String, preferences: LyricsPreferences) {
        self.currentLine = currentLine
        self.nextLine = nextLine
        self.preferences = preferences
    }
}
