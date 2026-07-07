// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PhraseBox",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PhraseBox", targets: ["PhraseBox"])
    ],
    targets: [
        .executableTarget(name: "PhraseBox")
    ]
)
