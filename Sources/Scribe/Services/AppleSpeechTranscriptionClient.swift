import AVFoundation
import Foundation
import Speech

struct AppleSpeechTranscriptionClient: Sendable {
  func supportedLocaleIdentifiers(for mode: AppleSpeechMode) async -> [String] {
    let locales: [Locale]
    if #available(macOS 26.0, *), mode != .legacy {
      if mode == .generalPurpose, SpeechTranscriber.isAvailable {
        locales = await SpeechTranscriber.supportedLocales
      } else {
        locales = await DictationTranscriber.supportedLocales
      }
    } else {
      locales = Array(SFSpeechRecognizer.supportedLocales())
    }

    return Array(
      Set(
        locales.map {
          $0.identifier.replacingOccurrences(of: "_", with: "-")
        }
      )
    ).sorted {
      let first = Locale.current.localizedString(forIdentifier: $0) ?? $0
      let second = Locale.current.localizedString(forIdentifier: $1) ?? $1
      return first.localizedCaseInsensitiveCompare(second) == .orderedAscending
    }
  }

  func transcribe(audioURL: URL, configuration: AppleSpeechConfiguration) async throws -> String {
    guard await PermissionManager.requestSpeechRecognition() else {
      throw DictationError.speechRecognitionDenied
    }

    if #available(macOS 26.0, *), configuration.mode != .legacy {
      return try await transcribeWithSpeechAnalyzer(
        audioURL: audioURL,
        configuration: configuration
      )
    }
    return try await transcribeWithLegacyRecognizer(
      audioURL: audioURL,
      configuration: configuration
    )
  }

  @available(macOS 26.0, *)
  private func transcribeWithSpeechAnalyzer(
    audioURL: URL,
    configuration: AppleSpeechConfiguration
  ) async throws -> String {
    let requestedLocale = Locale(identifier: configuration.normalizedLocaleIdentifier)

    if configuration.mode == .generalPurpose, SpeechTranscriber.isAvailable,
      let locale = await SpeechTranscriber.supportedLocale(equivalentTo: requestedLocale)
    {
      let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
      try await installAssets(for: [transcriber])
      return try await analyze(
        audioURL: audioURL,
        transcriber: transcriber,
        contextualPhrases: configuration.contextualPhrases
      )
    }

    guard let locale = await DictationTranscriber.supportedLocale(equivalentTo: requestedLocale)
    else {
      throw DictationError.appleSpeechUnavailable(
        "The locale \(configuration.normalizedLocaleIdentifier) is not supported on this Mac."
      )
    }

    let transcriber: DictationTranscriber
    if configuration.mode == .accentOptimized {
      let preset = DictationTranscriber.Preset.longDictation
      transcriber = DictationTranscriber(
        locale: locale,
        contentHints: preset.contentHints.union([.atypicalSpeech]),
        transcriptionOptions: preset.transcriptionOptions,
        reportingOptions: preset.reportingOptions,
        attributeOptions: preset.attributeOptions
      )
    } else {
      transcriber = DictationTranscriber(locale: locale, preset: .longDictation)
    }

    try await installAssets(for: [transcriber])
    return try await analyze(
      audioURL: audioURL,
      transcriber: transcriber,
      contextualPhrases: configuration.contextualPhrases
    )
  }

  @available(macOS 26.0, *)
  private func installAssets(for modules: [any SpeechModule]) async throws {
    let status = await AssetInventory.status(forModules: modules)
    guard status != .unsupported else {
      throw DictationError.appleSpeechUnavailable(
        "The selected Apple speech model is not supported on this Mac."
      )
    }
    guard status != .installed else { return }

    if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) {
      try await request.downloadAndInstall()
    }

    let finalStatus = await AssetInventory.status(forModules: modules)
    guard finalStatus == .installed else {
      let message =
        finalStatus == .downloading
        ? "The selected speech model is still downloading. Try again shortly."
        : "The selected speech model could not be installed."
      throw DictationError.appleSpeechUnavailable(
        message
      )
    }
  }

  @available(macOS 26.0, *)
  private func analysisContext(contextualPhrases: [String]) -> AnalysisContext {
    let context = AnalysisContext()
    let phrases =
      contextualPhrases
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    if !phrases.isEmpty {
      context.contextualStrings[.general] = phrases
    }
    return context
  }

  @available(macOS 26.0, *)
  private func analyze(
    audioURL: URL,
    transcriber: DictationTranscriber,
    contextualPhrases: [String]
  ) async throws -> String {
    let audioFile = try AVAudioFile(forReading: audioURL)
    let analyzer = SpeechAnalyzer(modules: [transcriber])
    try await analyzer.setContext(analysisContext(contextualPhrases: contextualPhrases))
    let resultTask = Task { try await collectResults(from: transcriber.results) }

    do {
      try await analyzer.start(inputAudioFile: audioFile, finishAfterFile: true)
      return try await resultTask.value
    } catch {
      resultTask.cancel()
      throw error
    }
  }

  @available(macOS 26.0, *)
  private func analyze(
    audioURL: URL,
    transcriber: SpeechTranscriber,
    contextualPhrases: [String]
  ) async throws -> String {
    let audioFile = try AVAudioFile(forReading: audioURL)
    let analyzer = SpeechAnalyzer(modules: [transcriber])
    try await analyzer.setContext(analysisContext(contextualPhrases: contextualPhrases))
    let resultTask = Task { try await collectResults(from: transcriber.results) }

    do {
      try await analyzer.start(inputAudioFile: audioFile, finishAfterFile: true)
      return try await resultTask.value
    } catch {
      resultTask.cancel()
      throw error
    }
  }

  @available(macOS 26.0, *)
  private func collectResults<S: AsyncSequence>(from results: S) async throws -> String
  where S.Element: SpeechModuleResult, S: Sendable {
    var segments: [String] = []
    for try await result in results {
      guard result.isFinal else { continue }
      let segment: String
      if let result = result as? DictationTranscriber.Result {
        segment = String(result.text.characters)
      } else if let result = result as? SpeechTranscriber.Result {
        segment = String(result.text.characters)
      } else {
        continue
      }
      let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty { segments.append(trimmed) }
    }
    let text = segments.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { throw DictationError.emptyTranscript }
    return text
  }

  private func transcribeWithLegacyRecognizer(
    audioURL: URL,
    configuration: AppleSpeechConfiguration
  ) async throws -> String {
    let locale = Locale(identifier: configuration.normalizedLocaleIdentifier)
    guard let recognizer = SFSpeechRecognizer(locale: locale) else {
      throw DictationError.appleSpeechUnavailable(
        "The locale \(configuration.normalizedLocaleIdentifier) is not supported on this Mac."
      )
    }
    guard recognizer.supportsOnDeviceRecognition else {
      throw DictationError.appleSpeechUnavailable(
        "On-device recognition is not available for \(configuration.normalizedLocaleIdentifier)."
      )
    }

    let request = SFSpeechURLRecognitionRequest(url: audioURL)
    request.requiresOnDeviceRecognition = true
    request.shouldReportPartialResults = false
    request.contextualStrings = configuration.contextualPhrases

    return try await withCheckedThrowingContinuation { continuation in
      let state = LegacyRecognitionState(continuation: continuation)
      let task = recognizer.recognitionTask(with: request) { result, error in
        if let error {
          state.finish(.failure(error))
        } else if let result, result.isFinal {
          let text = result.bestTranscription.formattedString
            .trimmingCharacters(in: .whitespacesAndNewlines)
          state.finish(text.isEmpty ? .failure(DictationError.emptyTranscript) : .success(text))
        }
      }
      state.retain(task)
    }
  }
}

private final class LegacyRecognitionState: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: CheckedContinuation<String, Error>?
  private var task: SFSpeechRecognitionTask?

  init(continuation: CheckedContinuation<String, Error>) {
    self.continuation = continuation
  }

  func retain(_ task: SFSpeechRecognitionTask) {
    lock.lock()
    if continuation == nil {
      lock.unlock()
      task.cancel()
      return
    }
    self.task = task
    lock.unlock()
  }

  func finish(_ result: Result<String, Error>) {
    lock.lock()
    guard let continuation else {
      lock.unlock()
      return
    }
    self.continuation = nil
    let task = self.task
    self.task = nil
    lock.unlock()

    task?.cancel()
    continuation.resume(with: result)
  }
}
