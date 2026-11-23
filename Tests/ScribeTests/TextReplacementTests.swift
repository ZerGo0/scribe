import XCTest

@testable import Scribe

final class TextReplacementTests: XCTestCase {
  func testReplacesWholeWordsIgnoringCase() {
    let rules = [TextReplacement(heard: "tail scale", replacement: "Tailscale")]
    XCTAssertEqual(
      TextReplacement.apply(rules, to: "Open Tail  Scale, then tail scales."),
      "Open Tailscale, then tail scales."
    )
  }

  func testKeepsWordsThatOnlyContainTheMatch() {
    let rules = [TextReplacement(heard: "Mül", replacement: "Müller")]
    XCTAssertEqual(TextReplacement.apply(rules, to: "Mülheim und Mül"), "Mülheim und Müller")
  }

  func testInsertsReplacementLiterally() {
    let rules = [TextReplacement(heard: "dollar sign", replacement: "$1")]
    XCTAssertEqual(TextReplacement.apply(rules, to: "a dollar sign"), "a $1")
  }

  func testVocabularySpellingFixesCase() {
    let rules = ["Tailscale", "Hugging Face"].map { TextReplacement(heard: $0, replacement: $0) }
    XCTAssertEqual(
      TextReplacement.apply(rules, to: "behind tailscale and hugging face"),
      "behind Tailscale and Hugging Face"
    )
  }

  func testIgnoresEmptyRules() {
    let rules = [TextReplacement(heard: "  ", replacement: "x")]
    XCTAssertEqual(TextReplacement.apply(rules, to: "keep this"), "keep this")
  }
}
