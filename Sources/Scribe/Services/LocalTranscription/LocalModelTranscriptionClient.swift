import Foundation

struct LocalModelTranscriptionClient: Sendable {
  func supportedLanguageCodes(for model: LocalSpeechModel) -> Set<String> {
    engine(for: model).supportedLanguageCodes
  }

  func isDownloaded(_ model: LocalSpeechModel) -> Bool {
    engine(for: model).isDownloaded()
  }

  func download(
    _ model: LocalSpeechModel,
    progress: @escaping @Sendable (Double) -> Void
  ) async throws {
    try await engine(for: model).download(progress: progress)
  }

  func delete(_ model: LocalSpeechModel) throws {
    try engine(for: model).delete()
  }

  func transcribe(
    chunks: [[Float]],
    model: LocalSpeechModel,
    language: String?,
    vocabulary: [String]
  ) async throws -> String {
    let engine = engine(for: model)
    guard engine.isDownloaded() else {
      throw DictationError.localModelNotDownloaded(model.displayName)
    }
    let text = try await engine.transcribe(
      chunks: chunks,
      language: language.flatMap { engine.supportedLanguageCodes.contains($0) ? $0 : nil },
      vocabulary: vocabulary
    )
      .split(whereSeparator: \.isWhitespace)
      .joined(separator: " ")
    guard !text.isEmpty else { throw DictationError.emptyTranscript }
    return text
  }

  private func engine(for model: LocalSpeechModel) -> any LocalSpeechEngine {
    ParakeetEngine(model: model)
  }
}
