import Foundation
import WhisperKit

struct WhisperEngine: LocalSpeechEngine {
  private let variant = "openai_whisper-large-v3-v20240930_turbo_632MB"
  private let directory = LocalModelStorage.directory(named: "whisperkit")
  private let downloadShare = 0.9

  var supportedLanguageCodes: Set<String> { Constants.languageCodes }

  private var readyMarker: URL {
    directory.appendingPathComponent("\(variant).ready")
  }

  func isDownloaded() -> Bool {
    guard let folder = modelFolder() else { return false }
    return FileManager.default.fileExists(atPath: folder.path)
  }

  func download(progress: @escaping @Sendable (Double) -> Void) async throws {
    let share = downloadShare
    let folder = try await WhisperKit.download(variant: variant, downloadBase: directory) {
      progress($0.fractionCompleted * share)
    }
    let whisper = try await loadedWhisper(folder: folder)
    await whisper.unloadModels()
    try Data(folder.path.utf8).write(to: readyMarker, options: .atomic)
    progress(1)
  }

  func delete() throws {
    try LocalModelStorage.remove(directory)
  }

  func transcribe(chunks: [[Float]], language: String?, vocabulary: [String]) async throws -> String {
    guard let folder = modelFolder() else {
      throw DictationError.localModelNotDownloaded(LocalSpeechModel.whisperLargeV3Turbo.displayName)
    }
    let whisper = try await loadedWhisper(folder: folder)
    let options = DecodingOptions(
      language: language,
      detectLanguage: language == nil,
      skipSpecialTokens: true,
      withoutTimestamps: true,
      promptTokens: promptTokens(for: vocabulary, tokenizer: whisper.tokenizer)
    )
    var texts: [String] = []
    for chunk in chunks {
      let results = try await whisper.transcribe(audioArray: chunk, decodeOptions: options)
      texts.append(results.map(\.text).joined(separator: " "))
    }
    await whisper.unloadModels()
    return texts.joined(separator: " ")
  }

  private func promptTokens(for vocabulary: [String], tokenizer: (any WhisperTokenizer)?) -> [Int]? {
    guard let prompt = Vocabulary.prompt(vocabulary), let tokenizer else { return nil }
    return tokenizer.encode(text: " " + prompt)
      .filter { $0 < tokenizer.specialTokens.specialTokenBegin }
  }

  private func modelFolder() -> URL? {
    guard let data = try? Data(contentsOf: readyMarker) else { return nil }
    return URL(fileURLWithPath: String(decoding: data, as: UTF8.self), isDirectory: true)
  }

  private func loadedWhisper(folder: URL) async throws -> WhisperKit {
    try await WhisperKit(
      WhisperKitConfig(
        modelFolder: folder.path,
        tokenizerFolder: directory,
        verbose: false,
        load: true,
        download: false
      )
    )
  }
}
