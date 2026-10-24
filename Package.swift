// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Matalogic",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Matalogic", targets: ["Matalogic"])
    ],
    targets: [
        .executableTarget(
            name: "Matalogic",
            path: "Sources/Matalogic"
        ),
        .testTarget(
            name: "MatalogicTests",
            dependencies: ["Matalogic"],
            path: "Tests/MatalogicTests"
        )
    ]
)
