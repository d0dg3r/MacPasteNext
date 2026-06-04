// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacPasteNext",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MacPasteNext", targets: ["MacPasteNext"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.0")
    ],
    targets: [
        .executableTarget(
            name: "MacPasteNext",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-warn-long-expression-type-checking=100"])
            ]
        )
    ]
)
