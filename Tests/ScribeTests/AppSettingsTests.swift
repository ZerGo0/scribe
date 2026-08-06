import XCTest

@testable import Scribe

@MainActor
final class AppSettingsTests: XCTestCase {
  func testSettingsPersistAcrossInstances() throws {
    let suite = "ScribeTests-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    let first = AppSettings(defaults: defaults)
    first.transcriptionProvider = .appleOnDevice
    first.provider = ProviderConfiguration(baseURL: "https://provider.test/v1", model: "speech-1")
    first.appleSpeech = AppleSpeechConfiguration(
      localeIdentifier: "en-GB",
      mode: .generalPurpose,
      contextualPhrases: ["Scribe", "Zergo"]
    )
    first.hotKey = HotKeyConfiguration(keyCode: 12, carbonModifiers: 256)
    first.launchAtLogin = true

    let second = AppSettings(defaults: defaults)
    XCTAssertEqual(second.transcriptionProvider, .appleOnDevice)
    XCTAssertEqual(second.provider, first.provider)
    XCTAssertEqual(second.appleSpeech, first.appleSpeech)
    XCTAssertEqual(second.hotKey, first.hotKey)
    XCTAssertTrue(second.launchAtLogin)
  }

  func testExistingSettingsDefaultToOpenAICompatibleProvider() throws {
    let suite = "ScribeTests-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    let existingProvider = ProviderConfiguration(
      baseURL: "https://provider.test/v1",
      model: "existing-model"
    )
    defaults.set(try JSONEncoder().encode(existingProvider), forKey: "provider")

    let settings = AppSettings(defaults: defaults)
    XCTAssertEqual(settings.transcriptionProvider, .openAICompatible)
    XCTAssertEqual(settings.provider, existingProvider)
    XCTAssertEqual(settings.appleSpeech, .default)
  }
}
