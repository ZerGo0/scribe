import Combine
import Foundation
import Security

@MainActor
final class AppSettings: ObservableObject {
  @Published var provider: ProviderConfiguration {
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
    provider =
      Self.decode(ProviderConfiguration.self, key: "provider", defaults: defaults) ?? .default
    hotKey = Self.decode(HotKeyConfiguration.self, key: "hotKey", defaults: defaults) ?? .default
    launchAtLogin = defaults.bool(forKey: "launchAtLogin")
  }

  private func persist() {
    if let data = try? encoder.encode(provider) {
      defaults.set(data, forKey: "provider")
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
