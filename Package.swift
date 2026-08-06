// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "scribe",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "Scribe", targets: ["Scribe"])
  ],
  dependencies: [
    .package(
      url: "https://github.com/BB9z/LAME-xcframework.git",
      exact: "3.100.3"
    )
  ],
  targets: [
    .executableTarget(
      name: "Scribe",
      dependencies: [
        .product(name: "LAME", package: "LAME-xcframework")
      ],
      linkerSettings: [
        .linkedFramework("AppKit"),
        .linkedFramework("AVFoundation"),
        .linkedFramework("Carbon"),
        .linkedFramework("Speech"),
        .linkedFramework("Security"),
        .linkedFramework("ServiceManagement"),
      ]
    ),
    .testTarget(name: "ScribeTests", dependencies: ["Scribe"]),
  ]
)
