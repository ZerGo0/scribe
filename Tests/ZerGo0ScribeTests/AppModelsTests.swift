import Carbon
import XCTest

@testable import ZerGo0Scribe

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
