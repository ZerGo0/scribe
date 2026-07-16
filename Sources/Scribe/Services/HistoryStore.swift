import Combine
import Foundation

@MainActor
final class HistoryStore: ObservableObject {
  @Published private(set) var transcripts: [Transcript] = []

  private let fileURL: URL
  private let retention: TimeInterval
  private let now: () -> Date

  init(
    fileURL: URL? = nil,
    retention: TimeInterval = 7 * 24 * 60 * 60,
    now: @escaping () -> Date = Date.init
  ) {
    self.fileURL = fileURL ?? Self.defaultFileURL
    self.retention = retention
    self.now = now
    load()
    pruneExpired()
  }

  var lastTranscript: Transcript? { transcripts.first }

  func add(_ transcript: Transcript) {
    transcripts.insert(transcript, at: 0)
    pruneExpired()
    save()
  }

  func delete(at offsets: IndexSet) {
    transcripts.remove(atOffsets: offsets)
    save()
  }

  func delete(id: UUID) {
    transcripts.removeAll { $0.id == id }
    save()
  }

  func delete(ids: Set<UUID>) {
    transcripts.removeAll { ids.contains($0.id) }
    save()
  }

  func transcripts(matching query: String) -> [Transcript] {
    let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return transcripts }
    return transcripts.filter { $0.text.localizedCaseInsensitiveContains(query) }
  }

  func clear() {
    transcripts.removeAll()
    save()
  }

  func pruneExpired() {
    let cutoff = now().addingTimeInterval(-retention)
    let originalCount = transcripts.count
    transcripts.removeAll { $0.createdAt < cutoff }
    if transcripts.count != originalCount { save() }
  }

  private func load() {
    guard let data = try? Data(contentsOf: fileURL),
      let decoded = try? JSONDecoder().decode([Transcript].self, from: data)
    else {
      return
    }
    transcripts = decoded.sorted { $0.createdAt > $1.createdAt }
  }

  private func save() {
    do {
      try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      let data = try JSONEncoder().encode(transcripts)
      try data.write(to: fileURL, options: .atomic)
    } catch {
      NSLog("Could not save transcript history: %@", error.localizedDescription)
    }
  }

  private static var defaultFileURL: URL {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    return base.appendingPathComponent("Scribe/history.json")
  }
}
