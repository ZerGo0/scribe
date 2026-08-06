import Carbon
import Foundation

enum TranscriptionProvider: String, Codable, CaseIterable, Equatable, Sendable {
  case openAICompatible
  case appleOnDevice

  var displayName: String {
    switch self {
    case .openAICompatible: "OpenAI-compatible"
    case .appleOnDevice: "Apple On-Device"
    }
  }
}

enum AppleSpeechMode: String, Codable, CaseIterable, Equatable, Sendable {
  case accentOptimized
  case dictation
  case generalPurpose
  case legacy

  var displayName: String {
    switch self {
    case .accentOptimized: "Heavy accent"
    case .dictation: "Dictation"
    case .generalPurpose: "General conversation"
    case .legacy: "Legacy recognizer"
    }
  }

  var detail: String {
    switch self {
    case .accentOptimized:
      "Uses Apple's atypical-speech hint for a heavy accent, lisp, or similar factors."
    case .dictation:
      "Uses the same on-device speech models as macOS system Dictation."
    case .generalPurpose:
      "Uses Apple's newer general-purpose Speech Transcriber when available."
    case .legacy:
      "Uses the older on-device recognizer for compatibility and comparison."
    }
  }
}

struct AppleSpeechConfiguration: Codable, Equatable, Sendable {
  var localeIdentifier: String
  var mode: AppleSpeechMode
  var contextualPhrases: [String]

  static let `default` = AppleSpeechConfiguration(
    localeIdentifier: "en-US",
    mode: .accentOptimized,
    contextualPhrases: []
  )

  var normalizedLocaleIdentifier: String {
    let trimmed = localeIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? Self.default.localeIdentifier : trimmed
  }
}

struct ProviderConfiguration: Codable, Equatable, Sendable {
  var baseURL: String
  var model: String

  static let `default` = ProviderConfiguration(
    baseURL: "https://api.openai.com/v1",
    model: "gpt-4o-mini-transcribe"
  )

  var normalizedBaseURL: URL? {
    let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    guard var components = URLComponents(string: trimmed),
      components.scheme == "https" || components.scheme == "http",
      components.host != nil
    else {
      return nil
    }
    while components.path.count > 1, components.path.hasSuffix("/") {
      components.path.removeLast()
    }
    return components.url
  }
}

struct HotKeyConfiguration: Codable, Equatable, Sendable {
  var keyCode: UInt32
  var carbonModifiers: UInt32

  static let `default` = HotKeyConfiguration(
    keyCode: UInt32(kVK_Space),
    carbonModifiers: UInt32(optionKey)
  )
}

struct Transcript: Codable, Equatable, Identifiable, Sendable {
  let id: UUID
  let text: String
  let createdAt: Date
  let duration: TimeInterval

  init(id: UUID = UUID(), text: String, createdAt: Date = Date(), duration: TimeInterval) {
    self.id = id
    self.text = text
    self.createdAt = createdAt
    self.duration = duration
  }
}

enum DictationError: LocalizedError, Equatable {
  case invalidProviderURL
  case missingAPIKey
  case microphoneDenied
  case speechRecognitionDenied
  case accessibilityDenied
  case emptyTranscript
  case recordingFailed(String)
  case requestFailed(String)
  case appleSpeechUnavailable(String)

  var errorDescription: String? {
    switch self {
    case .invalidProviderURL: "Enter a valid provider base URL."
    case .missingAPIKey: "Add an API key in Settings."
    case .microphoneDenied: "Microphone permission is required."
    case .speechRecognitionDenied: "Speech Recognition permission is required."
    case .accessibilityDenied: "Accessibility permission is required to paste transcripts."
    case .emptyTranscript: "The provider returned an empty transcript."
    case .recordingFailed(let message): "Recording failed: \(message)"
    case .requestFailed(let message): "Transcription failed: \(message)"
    case .appleSpeechUnavailable(let message): "Apple transcription is unavailable: \(message)"
    }
  }
}
