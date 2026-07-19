// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Destroyer",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(name: "DestroyerCore", targets: ["DestroyerCore"]),
        // Verifica eseguibile sotto Command Line Tools (dove XCTest/Testing non girano).
        // In Xcode usare invece la suite in Tests/DestroyerCoreTests (swift-testing).
        .executable(name: "destroyer-verify", targets: ["DestroyerVerify"]),
        // CLI headless per scansioni/report scriptabili e schedulazione vera.
        .executable(name: "destroyer", targets: ["DestroyerCLI"])
    ],
    targets: [
        .target(
            name: "DestroyerCore",
            path: "Sources/DestroyerCore"
        ),
        .executableTarget(
            name: "DestroyerVerify",
            dependencies: ["DestroyerCore"],
            path: "Sources/DestroyerVerify"
        ),
        .executableTarget(
            name: "DestroyerCLI",
            dependencies: ["DestroyerCore"],
            path: "Sources/DestroyerCLI"
        ),
        .testTarget(
            name: "DestroyerCoreTests",
            dependencies: ["DestroyerCore"],
            path: "Tests/DestroyerCoreTests"
        )
    ]
)
