import Foundation

public struct CodableColor: Codable, Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

public struct CodablePoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct LyricsPreferences: Codable, Equatable, Sendable {
    public var isOverlayVisible: Bool
    public var isLocked: Bool
    public var fontName: String
    public var fontSize: Double
    public var primaryColor: CodableColor
    public var gradientStartColor: CodableColor
    public var gradientEndColor: CodableColor
    public var isGradientEnabled: Bool
    public var opacity: Double
    public var windowOrigin: CodablePoint?

    public static let `default` = LyricsPreferences(
        isOverlayVisible: true,
        isLocked: false,
        fontName: "SF Pro Display",
        fontSize: 32,
        primaryColor: CodableColor(red: 1, green: 1, blue: 1),
        gradientStartColor: CodableColor(red: 1.0, green: 0.47, blue: 0.10),
        gradientEndColor: CodableColor(red: 0.35, green: 0.48, blue: 1.0),
        isGradientEnabled: true,
        opacity: 1,
        windowOrigin: nil
    )
}

public struct PreferencesStore {
    private let defaults: UserDefaults
    private let key = "lyricsPreferences"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() throws -> LyricsPreferences {
        guard let data = defaults.data(forKey: key) else {
            return .default
        }
        return try decoder.decode(LyricsPreferences.self, from: data)
    }

    public func save(_ preferences: LyricsPreferences) throws {
        let data = try encoder.encode(preferences)
        defaults.set(data, forKey: key)
    }
}
