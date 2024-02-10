// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "swift-ansi-picker",
    products: [
        .library(name: "Picker", targets: ["Picker"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Picker",
            dependencies: [],
            path: "Sources"
        ),
        .executableTarget(
            name: "example",
            dependencies: ["Picker"],
            path: "Examples"
        )
    ]
)
