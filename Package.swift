// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppleMusicLyrics",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "AppleMusicLyricsCore", targets: ["AppleMusicLyricsCore"]),
        .executable(name: "AppleMusicLyrics", targets: ["AppleMusicLyricsApp"])
    ],
    targets: [
        .target(
            name: "AppleMusicLyricsCore"
        ),
        .executableTarget(
            name: "AppleMusicLyricsApp",
            dependencies: ["AppleMusicLyricsCore"],
            path: "Sources/AppleMusicLyricsApp"
        ),
        .testTarget(
            name: "AppleMusicLyricsCoreTests",
            dependencies: ["AppleMusicLyricsCore"]
        ),
        .testTarget(
            name: "AppleMusicLyricsAppTests",
            dependencies: ["AppleMusicLyricsApp", "AppleMusicLyricsCore"]
        )
    ]
)
