import FluidAudio
import Foundation

struct ParakeetEngine: LocalSpeechEngine {
  private static let versionsSharingVocabularyModel: [AsrModelVersion] = [.ultra, .v2]

  private let version: AsrModelVersion
  private let fixedLanguageCode: String?
  private let vocabularyVariant = CtcModelVariant.ctc110m
  private let transcriberDownloadShare = 0.85
  private let dictationBoostingThresholds = VocabularyBoostingSession.Thresholds(
    cbw: 1,
    minSimilarity: 0.7
  )

  init(model: LocalSpeechModel) {
    version =
      switch model {
      case .parakeetUltra: .ultra
      case .parakeetEnglish: .v2
      }
    fixedLanguageCode = model.fixedLanguageCode
  }

  var supportedLanguageCodes: Set<String> {
    fixedLanguageCode.map { [$0] } ?? Set(Language.allCases.map(\.rawValue))
  }

  private var directory: URL {
    Self.directory(for: version)
  }

  private var vocabularyDirectory: URL {
    LocalModelStorage.directory(
      named: CtcModels.defaultCacheDirectory(for: vocabularyVariant).lastPathComponent
    )
  }

  func isDownloaded() -> Bool {
    Self.asrModelExists(version)
      && CtcModels.modelsExist(at: vocabularyDirectory)
  }

  func download(progress: @escaping @Sendable (Double) -> Void) async throws {
    let share = transcriberDownloadShare
    try await AsrModels.download(to: directory, version: version) { update in
      progress(update.fractionCompleted * share)
    }
    try await CtcModels.download(to: vocabularyDirectory, variant: vocabularyVariant) { update in
      progress(share + update.fractionCompleted * (1 - share))
    }
    progress(1)
  }

  func delete() throws {
    try LocalModelStorage.remove(directory)
    let vocabularyModelInUse = Self.versionsSharingVocabularyModel.contains {
      $0 != version && Self.asrModelExists($0)
    }
    if !vocabularyModelInUse { try LocalModelStorage.remove(vocabularyDirectory) }
  }

  func transcribe(chunks: [[Float]], language: String?, vocabulary: [String]) async throws -> String {
    let models = try await AsrModels.load(from: directory, version: version)
    let boosting = try? await vocabularyBoosting(for: vocabulary)
    let hint = fixedLanguageCode == nil ? language.flatMap(Language.init(rawValue:)) : nil
    let manager = AsrManager()
    do {
      try await manager.loadModels(models)
      var texts: [String] = []
      for chunk in chunks {
        var decoderState = TdtDecoderState.make(decoderLayers: version.decoderLayers)
        let result = try await manager.transcribe(chunk, decoderState: &decoderState, language: hint)
        var text = result.text
        if let boosting, let timings = result.tokenTimings,
          let rescored = await boosting.rescore(text: text, tokenTimings: timings, audioSamples: chunk),
          Self.keepsNumbers(original: text, rescored: rescored.text)
        {
          text = rescored.text
        }
        texts.append(text)
      }
      await manager.cleanup()
      return texts.joined(separator: " ")
    } catch {
      await manager.cleanup()
      throw error
    }
  }

  private static func directory(for version: AsrModelVersion) -> URL {
    LocalModelStorage.directory(
      named: AsrModels.defaultCacheDirectory(for: version).lastPathComponent
    )
  }

  private static func asrModelExists(_ version: AsrModelVersion) -> Bool {
    AsrModels.modelsExist(at: directory(for: version), version: version)
  }

  static func keepsNumbers(original: String, rescored: String) -> Bool {
    rescored.filter(\.isNumber).count >= original.filter(\.isNumber).count
  }

  private func vocabularyBoosting(for vocabulary: [String]) async throws -> VocabularyBoostingSession? {
    guard !vocabulary.isEmpty else { return nil }
    return try await VocabularyBoostingSession(
      vocabulary: CustomVocabularyContext(terms: vocabulary.map { CustomVocabularyTerm(text: $0) }),
      ctcModels: CtcModels.load(from: vocabularyDirectory, variant: vocabularyVariant),
      thresholds: dictationBoostingThresholds
    )
  }
}
