import XCTest

@testable import Scribe

final class ParakeetEngineTests: XCTestCase {
  func testRescoreKeepsTextWithSameNumbers() {
    XCTAssertTrue(
      ParakeetEngine.keepsNumbers(original: "Meet Tailskale at 14:30", rescored: "Meet Tailscale at 14:30")
    )
  }

  func testRescoreIsRejectedWhenItDropsNumbers() {
    XCTAssertFalse(
      ParakeetEngine.keepsNumbers(original: "The budget is $25,000", rescored: "The budget is Supabase")
    )
  }
}
