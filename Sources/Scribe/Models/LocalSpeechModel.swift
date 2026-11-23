import Foundation

enum LocalSpeechModel: String, Codable, CaseIterable, Equatable, Sendable {
  case parakeetUltra
  case parakeetEnglish

  static let `default` = LocalSpeechModel.parakeetUltra

  var displayName: String {
    switch self {
    case .parakeetUltra: "Parakeet Ultra"
    case .parakeetEnglish: "Parakeet English"
    }
  }

  var detail: String {
    switch self {
    case .parakeetUltra:
      "Supports English and 24 other European languages. Can switch between languages while you speak."
    case .parakeetEnglish:
      "English only, so it never switches to another language. Best if you dictate only in English."
    }
  }

  var approximateDownloadMegabytes: Int {
    switch self {
    case .parakeetUltra: 730
    case .parakeetEnglish: 570
    }
  }

  var fixedLanguageCode: String? {
    switch self {
    case .parakeetUltra: nil
    case .parakeetEnglish: "en"
    }
  }
}
