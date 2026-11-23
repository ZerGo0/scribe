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
      mode: .generalPurpose
    )
    first.vocabulary = ["Scribe", "Zergo"]
    first.replacements = [TextReplacement(heard: "so paar Base", replacement: "Supabase")]
    first.localModelLanguage = "de"
    first.audioProcessing = AudioProcessingOptions(
      removeLowHum: false,
      normalizeLevel: true,
      trimSilence: false
    )
    first.hotKey = HotKeyConfiguration(keyCode: 12, carbonModifiers: 256)
    first.launchAtLogin = true

    let second = AppSettings(defaults: defaults)
    XCTAssertEqual(second.transcriptionProvider, .appleOnDevice)
    XCTAssertEqual(second.provider, first.provider)
    XCTAssertEqual(second.appleSpeech, first.appleSpeech)
    XCTAssertEqual(second.vocabulary, ["Scribe", "Zergo"])
    XCTAssertEqual(second.replacements, first.replacements)
    XCTAssertEqual(second.localModel, .parakeetUltra)
    XCTAssertEqual(second.localModelLanguage, "de")
    XCTAssertEqual(second.audioProcessing, first.audioProcessing)
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
    XCTAssertEqual(settings.localModel, .default)
    XCTAssertEqual(settings.audioProcessing, .default)
    XCTAssertEqual(settings.vocabulary, [])
    XCTAssertEqual(settings.replacements, [])
    XCTAssertNil(settings.localModelLanguage)
  }

  func testAppleVocabularyMigratesToSharedVocabulary() throws {
    let suite = "ScribeTests-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    let legacy = #"{"localeIdentifier":"en-GB","mode":"dictation","contextualPhrases":["Scribe"]}"#
    defaults.set(Data(legacy.utf8), forKey: "appleSpeech")

    let settings = AppSettings(defaults: defaults)
    XCTAssertEqual(settings.vocabulary, ["Scribe"])
    XCTAssertEqual(settings.appleSpeech.localeIdentifier, "en-GB")
    XCTAssertEqual(settings.appleSpeech.mode, .dictation)
  }

  func testAutomaticLocalModelLanguageClearsStoredValue() throws {
    let suite = "ScribeTests-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    let settings = AppSettings(defaults: defaults)
    settings.localModelLanguage = "fr"
    settings.localModelLanguage = nil

    XCTAssertNil(AppSettings(defaults: defaults).localModelLanguage)
  }

  func testUnknownLocalModelFallsBackToDefault() throws {
    let suite = "ScribeTests-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    defaults.set("removedModel", forKey: "localModel")

    XCTAssertEqual(AppSettings(defaults: defaults).localModel, .default)
  }
}
