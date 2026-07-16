import XCTest

@testable import Scribe

@MainActor
final class HistoryStoreTests: XCTestCase {
  func testHistoryPrunesItemsOlderThanSevenDaysAndPersistsNewestFirst() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("ScribeHistoryTests-\(UUID().uuidString)")
    let file = directory.appendingPathComponent("history.json")
    defer { try? FileManager.default.removeItem(at: directory) }
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let store = HistoryStore(fileURL: file, now: { now })

    store.add(
      Transcript(text: "expired", createdAt: now.addingTimeInterval(-8 * 86_400), duration: 1))
    store.add(Transcript(text: "newer", createdAt: now.addingTimeInterval(-10), duration: 2))
    store.add(Transcript(text: "newest", createdAt: now, duration: 3))

    XCTAssertEqual(store.transcripts.map(\.text), ["newest", "newer"])

    let reloaded = HistoryStore(fileURL: file, now: { now })
    XCTAssertEqual(reloaded.transcripts.map(\.text), ["newest", "newer"])
  }

  func testClearRemovesAllPersistedHistory() {
    let file = FileManager.default.temporaryDirectory
      .appendingPathComponent("ScribeHistoryTests-\(UUID().uuidString)/history.json")
    let store = HistoryStore(fileURL: file)
    store.add(Transcript(text: "one", duration: 1))
    store.clear()

    XCTAssertTrue(store.transcripts.isEmpty)
    XCTAssertTrue(HistoryStore(fileURL: file).transcripts.isEmpty)
    try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
  }

  func testSearchIsCaseInsensitiveAndDeleteByIDPersists() {
    let file = FileManager.default.temporaryDirectory
      .appendingPathComponent("ScribeHistoryTests-\(UUID().uuidString)/history.json")
    let store = HistoryStore(fileURL: file)
    let matching = Transcript(text: "Meeting Notes", duration: 1)
    let other = Transcript(text: "Shopping list", duration: 1)
    store.add(other)
    store.add(matching)

    XCTAssertEqual(store.transcripts(matching: "  meeting ").map(\.id), [matching.id])
    XCTAssertEqual(store.transcripts(matching: "   ").count, 2)

    store.delete(id: matching.id)
    XCTAssertEqual(store.transcripts.map(\.id), [other.id])
    XCTAssertEqual(HistoryStore(fileURL: file).transcripts.map(\.id), [other.id])
    try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
  }
}
