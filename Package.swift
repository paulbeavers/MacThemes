// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacThemes",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MacThemesApp", targets: ["MacThemesApp"]),
        .executable(name: "macthemes", targets: ["macthemes-cli"]),
    ],
    targets: [
        .target(name: "MacThemesCore"),
        .executableTarget(name: "MacThemesApp", dependencies: ["MacThemesCore"]),
        .executableTarget(name: "macthemes-cli", dependencies: ["MacThemesCore"]),
    ]
)
