// swift-tools-version: 6.4

import PackageDescription

let package = Package(
  name: "scribe",
  platforms: [.macOS(.v15)],
  products: [
    .executable(name: "Scribe", targets: ["Scribe"])
  ],
  dependencies: [
    .package(
      url: "https://github.com/BB9z/LAME-xcframework.git",
      exact: "3.100.3"
    ),
    .package(
      url: "https://github.com/FluidInference/FluidAudio.git",
      exact: "0.18.4",
      traits: []
    ),
    .package(
      url: "https://github.com/soniqo/speech-swift.git",
      exact: "0.0.29"
    ),
    .package(
      url: "https://github.com/argmaxinc/WhisperKit.git",
      exact: "1.1.1"
    ),
  ],
  targets: [
    .executableTarget(
      name: "Scribe",
      dependencies: [
        .product(name: "LAME", package: "LAME-xcframework"),
        .product(name: "FluidAudio", package: "FluidAudio"),
        .product(name: "AudioCommon", package: "speech-swift"),
        .product(name: "Qwen3ASR", package: "speech-swift"),
        .product(name: "WhisperKit", package: "WhisperKit"),
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
