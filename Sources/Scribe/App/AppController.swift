import AppKit
import Combine
import Foundation

@MainActor
final class AppController: ObservableObject {
  @Published private(set) var isRecording = false
  @Published private(set) var queuedCount = 0
  @Published var lastError: String?
  @Published private(set) var inputWarning: String?

  let settings: AppSettings
  let history: HistoryStore
  let localModels = LocalModelLibrary()

  private let keychain = KeychainStore()
  private let recorder = AudioRecorder()
  private let hotKey = GlobalHotKey()
  private let clipboard = ClipboardInserter()
  private let sounds = SoundFeedback()
  private let pill = RecordingPillController()
  private let client = TranscriptionClient()
  private let remoteClient = OpenAITranscriptionClient()
  private var queue: TranscriptionQueue!
  private var isStopping = false

  init(settings: AppSettings? = nil, history: HistoryStore? = nil) {
    self.settings = settings ?? AppSettings()
    self.history = history ?? HistoryStore()
    queue = TranscriptionQueue(
      client: client,
      completion: { [weak self] job, result in self?.complete(job: job, result: result) },
      depthChanged: { [weak self] count in self?.queueDepthChanged(count) }
    )
    registerHotKey(self.settings.hotKey)
    recorder.prepareIfAuthorized()
  }

  func toggleDictation() {
    let targetScreen = isRecording ? nil : ActiveScreenResolver.activeScreen()
    Task {
      if isRecording {
        await stopDictation()
      } else {
        await startDictation(on: targetScreen)
      }
    }
  }

  func startDictation(on targetScreen: NSScreen? = nil) async {
    guard !isRecording else { return }
    do {
      switch settings.transcriptionProvider {
      case .openAICompatible:
        guard settings.provider.normalizedBaseURL != nil else {
          throw DictationError.invalidProviderURL
        }
        guard !keychain.readAPIKey().isEmpty else { throw DictationError.missingAPIKey }
      case .appleOnDevice:
        guard await PermissionManager.requestSpeechRecognition() else {
          throw DictationError.speechRecognitionDenied
        }
      case .localModel:
        guard localModels.isDownloaded(settings.localModel) else {
          throw DictationError.localModelNotDownloaded(settings.localModel.displayName)
        }
      }
      let startedAt = try await recorder.start()
      lastError = nil
      isRecording = true
      pill.show(.recording(startedAt: startedAt), on: targetScreen)
      sounds.play(.started)
    } catch {
      report(error)
    }
  }

  func stopDictation() async {
    guard isRecording, !isStopping else { return }
    isStopping = true
    defer { isStopping = false }
    pill.show(.transcribing, on: nil)
    let recording: AudioRecorder.Recording
    do {
      recording = try await recorder.stop()
      isRecording = false
      inputWarning = recording.warning?.message
    } catch {
      isRecording = false
      pill.hide()
      report(error)
      return
    }

    let job = TranscriptionQueue.Job(
      audioURL: recording.url,
      duration: recording.duration,
      request: TranscriptionRequest(
        provider: settings.transcriptionProvider,
        remoteConfiguration: settings.provider,
        appleConfiguration: settings.appleSpeech,
        localModel: settings.localModel,
        localModelLanguage: settings.localModelLanguage,
        vocabulary: settings.vocabulary,
        replacements: settings.replacements,
        audioProcessing: settings.audioProcessing,
        textCleanup: settings.textCleanup,
        apiKey: settings.transcriptionProvider == .openAICompatible ? keychain.readAPIKey() : ""
      )
    )
    Task { await queue.enqueue(job) }
  }

  func updateHotKey(_ configuration: HotKeyConfiguration) {
    do {
      try hotKey.register(configuration) { [weak self] in self?.toggleDictation() }
      settings.hotKey = configuration
      lastError = nil
    } catch {
      report(error)
    }
  }

  func apiKey() -> String { keychain.readAPIKey() }

  func saveAPIKey(_ value: String) {
    do {
      try keychain.writeAPIKey(value.trimmingCharacters(in: .whitespacesAndNewlines))
      lastError = nil
    } catch {
      report(error)
    }
  }

  func fetchModels(apiKey: String) async throws -> [String] {
    try await remoteClient.models(provider: settings.provider, apiKey: apiKey)
  }

  func appleSpeechLocaleIdentifiers(for mode: AppleSpeechMode) async -> [String] {
    await AppleSpeechTranscriptionClient().supportedLocaleIdentifiers(for: mode)
  }

  func setLaunchAtLogin(_ enabled: Bool) {
    do {
      try LaunchAtLoginManager.setEnabled(enabled)
      settings.launchAtLogin = enabled
      lastError = nil
    } catch {
      settings.launchAtLogin = false
      report(error)
    }
  }

  private func queueDepthChanged(_ count: Int) {
    queuedCount = count
    if count == 0, !isRecording { pill.hide() }
  }

  private func registerHotKey(_ configuration: HotKeyConfiguration) {
    do {
      try hotKey.register(configuration) { [weak self] in self?.toggleDictation() }
    } catch {
      report(error)
    }
  }

  private func complete(job: TranscriptionQueue.Job, result: Result<String, Error>) {
    defer { try? FileManager.default.removeItem(at: job.audioURL) }
    switch result {
    case .success(let text):
      let transcript = Transcript(text: text, duration: job.duration)
      history.add(transcript)
      Task {
        do {
          try await clipboard.insert(text)
          sounds.play(.completed)
          lastError = nil
        } catch {
          report(error)
        }
      }
    case .failure(let error):
      report(error)
    }
  }

  private func report(_ error: Error) {
    lastError = error.localizedDescription
    sounds.play(.failed)
  }
}
