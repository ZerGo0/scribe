import Combine
import Foundation
import Security

@MainActor
final class AppSettings: ObservableObject {
  @Published var transcriptionProvider: TranscriptionProvider {
    didSet { persist() }
  }

  @Published var provider: ProviderConfiguration {
    didSet { persist() }
  }

  @Published var appleSpeech: AppleSpeechConfiguration {
    didSet { persist() }
  }

  @Published var vocabulary: [String] {
    didSet { persist() }
  }

  @Published var replacements: [TextReplacement] {
    didSet { persist() }
  }

  @Published var localModel: LocalSpeechModel {
    didSet { persist() }
  }

  @Published var localModelLanguage: String? {
    didSet { persist() }
  }

  @Published var audioProcessing: AudioProcessingOptions {
    didSet { persist() }
  }

  @Published var textCleanup: TextCleanupOptions {
    didSet { persist() }
  }

  @Published var hotKey: HotKeyConfiguration {
    didSet { persist() }
  }

  @Published var launchAtLogin: Bool {
    didSet { persist() }
  }

  private let defaults: UserDefaults
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    transcriptionProvider =
      defaults.string(forKey: "transcriptionProvider")
      .flatMap(TranscriptionProvider.init(rawValue:)) ?? .openAICompatible
    provider =
      Self.decode(ProviderConfiguration.self, key: "provider", defaults: defaults) ?? .default
    appleSpeech =
      Self.decode(AppleSpeechConfiguration.self, key: "appleSpeech", defaults: defaults) ?? .default
    vocabulary =
      defaults.stringArray(forKey: "vocabulary")
      ?? Self.decode(LegacyAppleSpeechVocabulary.self, key: "appleSpeech", defaults: defaults)?
      .contextualPhrases
      ?? []
    replacements =
      Self.decode([TextReplacement].self, key: "replacements", defaults: defaults) ?? []
    localModel =
      defaults.string(forKey: "localModel")
      .flatMap(LocalSpeechModel.init(rawValue:)) ?? .default
    localModelLanguage = defaults.string(forKey: "localModelLanguage")
    audioProcessing =
      Self.decode(AudioProcessingOptions.self, key: "audioProcessing", defaults: defaults)
      ?? .default
    textCleanup =
      Self.decode(TextCleanupOptions.self, key: "textCleanup", defaults: defaults) ?? .default
    hotKey = Self.decode(HotKeyConfiguration.self, key: "hotKey", defaults: defaults) ?? .default
    launchAtLogin = defaults.bool(forKey: "launchAtLogin")
  }

  private func persist() {
    defaults.set(transcriptionProvider.rawValue, forKey: "transcriptionProvider")
    if let data = try? encoder.encode(provider) {
      defaults.set(data, forKey: "provider")
    }
    if let data = try? encoder.encode(appleSpeech) {
      defaults.set(data, forKey: "appleSpeech")
    }
    defaults.set(vocabulary, forKey: "vocabulary")
    if let data = try? encoder.encode(replacements) {
      defaults.set(data, forKey: "replacements")
    }
    defaults.set(localModel.rawValue, forKey: "localModel")
    if let localModelLanguage {
      defaults.set(localModelLanguage, forKey: "localModelLanguage")
    } else {
      defaults.removeObject(forKey: "localModelLanguage")
    }
    if let data = try? encoder.encode(audioProcessing) {
      defaults.set(data, forKey: "audioProcessing")
    }
    if let data = try? encoder.encode(textCleanup) {
      defaults.set(data, forKey: "textCleanup")
    }
    if let data = try? encoder.encode(hotKey) {
      defaults.set(data, forKey: "hotKey")
    }
    defaults.set(launchAtLogin, forKey: "launchAtLogin")
  }

  private static func decode<T: Decodable>(
    _ type: T.Type,
    key: String,
    defaults: UserDefaults
  ) -> T? {
    guard let data = defaults.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(type, from: data)
  }
}

private struct LegacyAppleSpeechVocabulary: Decodable {
  let contextualPhrases: [String]
}

struct KeychainStore: Sendable {
  private let service = "com.zergo0.scribe"
  private let account = "provider-api-key"

  func readAPIKey() -> String {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data
    else {
      return ""
    }
    return String(decoding: data, as: UTF8.self)
  }

  func writeAPIKey(_ value: String) throws {
    let base: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    SecItemDelete(base as CFDictionary)
    guard !value.isEmpty else { return }

    var item = base
    item[kSecValueData as String] = Data(value.utf8)
    item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    let status = SecItemAdd(item as CFDictionary, nil)
    guard status == errSecSuccess else {
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
  }
}
