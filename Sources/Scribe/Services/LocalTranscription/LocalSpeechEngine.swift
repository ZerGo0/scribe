import Foundation

protocol LocalSpeechEngine: Sendable {
  var supportedLanguageCodes: Set<String> { get }
  func isDownloaded() -> Bool
  func download(progress: @escaping @Sendable (Double) -> Void) async throws
  func delete() throws
  func transcribe(chunks: [[Float]], language: String?, vocabulary: [String]) async throws -> String
}

enum LocalModelStorage {
  static func directory(named name: String) -> URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Scribe", isDirectory: true)
      .appendingPathComponent("Models", isDirectory: true)
      .appendingPathComponent(name, isDirectory: true)
  }

  static func remove(_ directory: URL) throws {
    guard FileManager.default.fileExists(atPath: directory.path) else { return }
    try FileManager.default.removeItem(at: directory)
  }
}
