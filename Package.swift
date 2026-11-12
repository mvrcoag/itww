// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "itww",
    platforms: [
        .macOS("27.0")
    ],
    products: [
        .executable(name: "itww", targets: ["itww"])
    ],
    targets: [
        .executableTarget(
            name: "itww",
            path: "Sources/itww",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("FoundationModels"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .testTarget(
            name: "itwwTests",
            dependencies: ["itww"],
            path: "Tests/itwwTests"
        )
    ]
)
