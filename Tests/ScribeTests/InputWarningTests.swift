import XCTest

@testable import Scribe

final class InputWarningTests: XCTestCase {
  func testClippingComesFirst() {
    XCTAssertEqual(
      InputWarning(level: InputLevel(peak: 1, isClipped: true), usesBluetooth: true), .clipped)
  }

  func testQuietInputWarns() {
    XCTAssertEqual(
      InputWarning(level: InputLevel(peak: 0.005, isClipped: false), usesBluetooth: false), .quiet)
  }

  func testBluetoothWarnsWhenLevelIsGood() {
    XCTAssertEqual(
      InputWarning(level: InputLevel(peak: 0.5, isClipped: false), usesBluetooth: true), .bluetooth)
  }

  func testGoodInputHasNoWarning() {
    XCTAssertNil(InputWarning(level: InputLevel(peak: 0.5, isClipped: false), usesBluetooth: false))
  }
}
