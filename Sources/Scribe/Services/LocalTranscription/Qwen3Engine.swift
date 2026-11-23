import AudioCommon
import Foundation
import Qwen3ASR

struct Qwen3Engine: LocalSpeechEngine {
  private let modelID = "aufklarer/Qwen3-ASR-0.6B-MLX-5bit"
  private let tokenizerFiles = ["vocab.json", "merges.txt", "tokenizer_config.json"]
  private let directory = LocalModelStorage.directory(named: "qwen3-asr-0.6b-mlx-5bit")
  private let promptLocale = Locale(identifier: "en")

  let supportedLanguageCodes: Set<String> = [
    "ar", "cs", "da", "de", "el", "en", "es", "fa", "fi", "fil", "fr", "hi", "hu", "id", "it",
    "ja", "ko", "mk", "ms", "nl", "pl", "pt", "ro", "ru", "sv", "th", "tr", "vi", "yue", "zh",
  ]

  func isDownloaded() -> Bool {
    HuggingFaceDownloader.weightsExist(in: directory)
      && tokenizerFiles.allSatisfy {
        FileManager.default.fileExists(atPath: directory.appendingPathComponent($0).path)
      }
  }

  func download(progress: @escaping @Sendable (Double) -> Void) async throws {
    try await HuggingFaceDownloader.downloadWeights(
      modelId: modelID,
      to: directory,
      additionalFiles: tokenizerFiles,
      progressHandler: progress
    )
  }

  func delete() throws {
    try LocalModelStorage.remove(directory)
  }

  func transcribe(chunks: [[Float]], language: String?, vocabulary: [String]) async throws -> String {
    let model = try await Qwen3ASRModel.fromPretrained(
      modelId: modelID,
      cacheDir: directory,
      offlineMode: true
    )
    defer { model.unload() }
    let options = Qwen3DecodingOptions(
      language: language.flatMap(promptLocale.localizedString(forLanguageCode:)),
      context: Vocabulary.prompt(vocabulary)
    )
    return try chunks.map { try model.transcribeThrowing(audio: $0, options: options) }
      .joined(separator: " ")
  }
}
