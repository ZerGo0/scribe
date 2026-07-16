// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "zergo0scribe",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "ZerGo0Scribe", targets: ["ZerGo0Scribe"])
  ],
  targets: [
    .executableTarget(
      name: "ZerGo0Scribe",
      linkerSettings: [
        .linkedFramework("AppKit"),
        .linkedFramework("AVFoundation"),
        .linkedFramework("Carbon"),
        .linkedFramework("Security"),
        .linkedFramework("ServiceManagement"),
      ]
    ),
    .testTarget(name: "ZerGo0ScribeTests", dependencies: ["ZerGo0Scribe"]),
  ]
)
