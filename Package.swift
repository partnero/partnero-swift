// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Partnero",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "Partnero", targets: ["Partnero"]),
    ],
    targets: [
        .target(name: "Partnero", resources: [.copy("PrivacyInfo.xcprivacy")]),
        .testTarget(name: "PartneroTests", dependencies: ["Partnero"]),
    ]
)
