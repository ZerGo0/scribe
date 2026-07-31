import AppKit
import Combine
import Foundation

@MainActor
final class AppController: ObservableObject {
  @Published private(set) var isRecording = false
  @Published private(set) var queuedCount = 0
  @Published var lastError: String?

  let settings: AppSettings
  let history: HistoryStore

  private let keychain = KeychainStore()
  private let recorder = AudioRecorder()
  private let hotKey = GlobalHotKey()
  private let clipboard = ClipboardInserter()
  private let sounds = SoundFeedback()
  private let pill = RecordingPillController()
  private let client = OpenAITranscriptionClient()
  private var queue: TranscriptionQueue!

  init(settings: AppSettings? = nil, history: HistoryStore? = nil) {
    self.settings = settings ?? AppSettings()
    self.history = history ?? HistoryStore()
    queue = TranscriptionQueue(
      client: client,
      completion: { [weak self] job, result in self?.complete(job: job, result: result) },
      depthChanged: { [weak self] count in self?.queuedCount = count }
    )
    registerHotKey(self.settings.hotKey)
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
      guard settings.provider.normalizedBaseURL != nil else {
        throw DictationError.invalidProviderURL
      }
      guard !keychain.readAPIKey().isEmpty else { throw DictationError.missingAPIKey }
      let startedAt = try await recorder.start()
      lastError = nil
      isRecording = true
      pill.show(startedAt: startedAt, on: targetScreen)
      sounds.play(.started)
    } catch {
      report(error)
    }
  }

  func stopDictation() async {
    guard isRecording else { return }
    let recording: AudioRecorder.Recording
    do {
      recording = try recorder.stop()
      isRecording = false
      pill.hide()
    } catch {
      isRecording = false
      pill.hide()
      report(error)
      return
    }

    do {
      let mp3URL = try await Task.detached(priority: .userInitiated) {
        try MP3Encoder.encode(recording.url)
      }.value
      try? FileManager.default.removeItem(at: recording.url)
      let job = TranscriptionQueue.Job(
        audioURL: mp3URL,
        duration: recording.duration,
        provider: settings.provider,
        apiKey: keychain.readAPIKey()
      )
      Task { await queue.enqueue(job) }
    } catch {
      try? FileManager.default.removeItem(at: recording.url)
      report(error)
    }
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
    try await client.models(provider: settings.provider, apiKey: apiKey)
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

  func copyLastTranscript() {
    guard let text = history.lastTranscript?.text else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
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
