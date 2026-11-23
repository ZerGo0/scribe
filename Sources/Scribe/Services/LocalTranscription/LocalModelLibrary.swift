import Combine
import Foundation

@MainActor
final class LocalModelLibrary: ObservableObject {
  @Published private(set) var downloaded: Set<LocalSpeechModel> = []
  @Published private(set) var downloadProgress: [LocalSpeechModel: Double] = [:]
  @Published private(set) var errorMessage: String?

  private let client: LocalModelTranscriptionClient

  init(client: LocalModelTranscriptionClient = LocalModelTranscriptionClient()) {
    self.client = client
    refresh()
  }

  func supportedLanguageCodes(for model: LocalSpeechModel) -> Set<String> {
    client.supportedLanguageCodes(for: model)
  }

  func isDownloaded(_ model: LocalSpeechModel) -> Bool {
    downloaded.contains(model)
  }

  func download(_ model: LocalSpeechModel) {
    guard downloadProgress[model] == nil else { return }
    downloadProgress[model] = 0
    errorMessage = nil
    Task {
      do {
        try await client.download(model) { fraction in
          Task { @MainActor in
            guard self.downloadProgress[model] != nil else { return }
            self.downloadProgress[model] = fraction
          }
        }
      } catch {
        errorMessage = error.localizedDescription
      }
      downloadProgress[model] = nil
      refresh()
    }
  }

  func delete(_ model: LocalSpeechModel) {
    guard downloadProgress[model] == nil else { return }
    do {
      try client.delete(model)
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
    refresh()
  }

  private func refresh() {
    downloaded = Set(LocalSpeechModel.allCases.filter(client.isDownloaded))
  }
}
