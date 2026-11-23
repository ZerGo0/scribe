import Carbon
import XCTest

@testable import Scribe

final class AppModelsTests: XCTestCase {
  func testProviderNormalizesTrailingSlashWithoutDroppingPath() {
    let provider = ProviderConfiguration(baseURL: "https://example.com/v1/", model: "whisper")
    XCTAssertEqual(provider.normalizedBaseURL?.absoluteString, "https://example.com/v1")
  }

  func testProviderRejectsInvalidAndUnsupportedURLs() {
    XCTAssertNil(ProviderConfiguration(baseURL: "example.com/v1", model: "m").normalizedBaseURL)
    XCTAssertNil(
      ProviderConfiguration(baseURL: "ftp://example.com/v1", model: "m").normalizedBaseURL)
  }

  func testAppleSpeechDefaultsToAccentOptimizedEnglishUS() {
    XCTAssertEqual(AppleSpeechConfiguration.default.mode, .accentOptimized)
    XCTAssertEqual(AppleSpeechConfiguration.default.normalizedLocaleIdentifier, "en-US")
  }

  func testAppleSpeechFallsBackToDefaultLocaleForWhitespace() {
    let configuration = AppleSpeechConfiguration(
      localeIdentifier: "   ",
      mode: .dictation
    )
    XCTAssertEqual(configuration.normalizedLocaleIdentifier, "en-US")
  }

  func testVocabularyTrimsEntriesAndDropsEmptyAndDuplicateTerms() {
    XCTAssertEqual(
      Vocabulary.terms(from: " Scribe, ,Zergo,scribe , Hugging Face,"),
      ["Scribe", "Zergo", "Hugging Face"]
    )
  }

  func testEnglishLocalModelAlwaysUsesEnglishForCleanup() {
    XCTAssertEqual(localRequest(model: .parakeetEnglish, language: "de").spokenLanguageCode, "en")
    XCTAssertEqual(localRequest(model: .parakeetUltra, language: "de").spokenLanguageCode, "de")
    XCTAssertNil(localRequest(model: .parakeetUltra, language: nil).spokenLanguageCode)
  }

  private func localRequest(model: LocalSpeechModel, language: String?) -> TranscriptionRequest {
    TranscriptionRequest(
      provider: .localModel,
      remoteConfiguration: .default,
      appleConfiguration: .default,
      localModel: model,
      localModelLanguage: language,
      vocabulary: [],
      replacements: [],
      audioProcessing: .default,
      textCleanup: .default,
      apiKey: ""
    )
  }

  func testVocabularyPromptIsNilWithoutTerms() {
    XCTAssertNil(Vocabulary.prompt([]))
    XCTAssertEqual(Vocabulary.prompt(["Scribe", "Zergo"]), "Scribe, Zergo")
  }

  func testLocalModelNotDownloadedErrorNamesTheModel() {
    XCTAssertEqual(
      DictationError.localModelNotDownloaded(LocalSpeechModel.parakeetUltra.displayName)
        .errorDescription,
      "Download the Parakeet Ultra model in Settings."
    )
  }

  func testAudioProcessingIsEnabledWhenAnyStepIsOn() {
    XCTAssertTrue(AudioProcessingOptions.default.isEnabled)
    XCTAssertFalse(
      AudioProcessingOptions(removeLowHum: false, normalizeLevel: false, trimSilence: false)
        .isEnabled
    )
  }

  @MainActor
  func testHotKeyDisplayNameUsesCarbonModifiers() {
    let key = HotKeyConfiguration(
      keyCode: UInt32(kVK_Space),
      carbonModifiers: UInt32(controlKey | optionKey)
    )
    XCTAssertEqual(GlobalHotKey.displayName(for: key), "⌃⌥Space")
  }

  @MainActor
  func testBareF14IsAcceptedAndDisplayed() throws {
    let key = try XCTUnwrap(
      GlobalHotKey.configuration(keyCode: UInt16(kVK_F14), modifierFlags: [])
    )

    XCTAssertEqual(key.keyCode, UInt32(kVK_F14))
    XCTAssertEqual(key.carbonModifiers, 0)
    XCTAssertEqual(GlobalHotKey.displayName(for: key), "F14")
  }

  @MainActor
  func testBareLetterIsRejected() {
    XCTAssertNil(GlobalHotKey.configuration(keyCode: UInt16(kVK_ANSI_A), modifierFlags: []))
  }
}
