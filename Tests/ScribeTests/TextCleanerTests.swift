import XCTest

@testable import Scribe

final class TextCleanerTests: XCTestCase {
  private let all = TextCleanupOptions.default

  func testRemovesEnglishFillersAndKeepsSentenceCase() {
    XCTAssertEqual(
      TextCleaner.cleaned("Um, I think, uh, we should go. Uh, so let's start.", options: all, languageCode: "en"),
      "I think we should go. So let's start."
    )
  }

  func testKeepsGermanWordsThatAreEnglishFillers() {
    XCTAssertEqual(
      TextCleaner.cleaned("Ich komme, äh, um acht Uhr. Er wartet.", options: all, languageCode: "de"),
      "Ich komme um acht Uhr. Er wartet."
    )
  }

  func testLeavesFillersWhenLanguageIsUnknown() {
    let options = TextCleanupOptions(removeFillers: true, removeRepeatedWords: false, applySpokenLineBreaks: false)
    XCTAssertEqual(TextCleaner.cleaned("um", options: options, languageCode: nil), "um")
  }

  func testRemovesStutterRepeatsButKeepsMeaningfulRepeats() {
    XCTAssertEqual(
      TextCleaner.cleaned("I I think the the plan had had a very very good start.", options: all, languageCode: "en"),
      "I think the plan had had a very very good start."
    )
  }

  func testSpokenLineBreaksBecomeNewlines() {
    XCTAssertEqual(
      TextCleaner.cleaned(
        "Dear team, new paragraph. Thanks for the update. New line, best regards",
        options: all,
        languageCode: "en"
      ),
      "Dear team,\n\nThanks for the update.\nBest regards"
    )
    XCTAssertEqual(
      TextCleaner.cleaned("Erster Punkt, neue Zeile, zweiter Punkt", options: all, languageCode: "de"),
      "Erster Punkt,\nZweiter Punkt"
    )
  }

  func testDisabledOptionsLeaveTextUnchanged() {
    let none = TextCleanupOptions(removeFillers: false, removeRepeatedWords: false, applySpokenLineBreaks: false)
    let text = "Um, I I said new line here."
    XCTAssertEqual(TextCleaner.cleaned(text, options: none, languageCode: "en"), text)
  }

  func testDetectsLanguageOfLongerText() {
    XCTAssertEqual(
      TextCleaner.detectedLanguage(of: "Please meet me at the train station at half past seven tonight."),
      "en"
    )
  }
}
