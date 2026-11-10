// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GmailKeys",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "GmailKeys",
            path: "Sources/GmailKeys"
        )
    ]
)
