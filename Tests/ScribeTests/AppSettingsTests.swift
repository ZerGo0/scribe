import XCTest

@testable import Scribe

@MainActor
final class AppSettingsTests: XCTestCase {
  func testSettingsPersistAcrossInstances() throws {
    let suite = "ScribeTests-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    let first = AppSettings(defaults: defaults)
    first.provider = ProviderConfiguration(baseURL: "https://provider.test/v1", model: "speech-1")
    first.hotKey = HotKeyConfiguration(keyCode: 12, carbonModifiers: 256)
    first.launchAtLogin = true

    let second = AppSettings(defaults: defaults)
    XCTAssertEqual(second.provider, first.provider)
    XCTAssertEqual(second.hotKey, first.hotKey)
    XCTAssertTrue(second.launchAtLogin)
  }
}
