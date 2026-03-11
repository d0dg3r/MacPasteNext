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
    targets: [
        .executableTarget(
            name: "MacPasteNext",
            dependencies: [],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-warn-long-expression-type-checking=100"])
            ]
        )
    ]
)
