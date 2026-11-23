import Foundation

enum LocalSpeechModel: String, Codable, CaseIterable, Equatable, Sendable {
  case parakeetV3
  case qwen3ASR
  case whisperLargeV3Turbo

  static let `default` = LocalSpeechModel.parakeetV3

  var displayName: String {
    switch self {
    case .parakeetV3: "Parakeet TDT v3"
    case .qwen3ASR: "Qwen3-ASR 0.6B (5-bit)"
    case .whisperLargeV3Turbo: "Whisper Large-v3 Turbo"
    }
  }

  var detail: String {
    switch self {
    case .parakeetV3:
      "Fastest. Runs on the Neural Engine. Supports English and 24 other European languages."
    case .qwen3ASR:
      "Most accurate in benchmarks. Runs on the GPU. Supports 52 languages and dialects."
    case .whisperLargeV3Turbo:
      "Runs on the Neural Engine. Supports 99 languages."
    }
  }

  var approximateDownloadMegabytes: Int {
    switch self {
    case .parakeetV3: 590
    case .qwen3ASR: 1_100
    case .whisperLargeV3Turbo: 630
    }
  }
}
