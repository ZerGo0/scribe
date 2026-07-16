// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "scribe",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "Scribe", targets: ["Scribe"])
  ],
  targets: [
    .executableTarget(
      name: "Scribe",
      linkerSettings: [
        .linkedFramework("AppKit"),
        .linkedFramework("AVFoundation"),
        .linkedFramework("Carbon"),
        .linkedFramework("Security"),
        .linkedFramework("ServiceManagement"),
      ]
    ),
    .testTarget(name: "ScribeTests", dependencies: ["Scribe"]),
  ]
)
