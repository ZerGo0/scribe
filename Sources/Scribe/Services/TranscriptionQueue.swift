import Foundation

actor TranscriptionQueue {
  struct Job: Sendable {
    let audioURL: URL
    let duration: TimeInterval
    let provider: ProviderConfiguration
    let apiKey: String
  }

  typealias Completion = @MainActor @Sendable (Job, Result<String, Error>) -> Void
  typealias DepthChanged = @MainActor @Sendable (Int) -> Void

  private let client: any Transcribing
  private var jobs: [Job] = []
  private var isProcessing = false
  private let completion: Completion
  private let depthChanged: DepthChanged

  init(
    client: any Transcribing,
    completion: @escaping Completion,
    depthChanged: @escaping DepthChanged
  ) {
    self.client = client
    self.completion = completion
    self.depthChanged = depthChanged
  }

  func enqueue(_ job: Job) {
    jobs.append(job)
    notifyDepth()
    guard !isProcessing else { return }
    isProcessing = true
    Task { await processJobs() }
  }

  func pendingCount() -> Int { jobs.count }

  private func processJobs() async {
    while !jobs.isEmpty {
      let job = jobs[0]
      let result: Result<String, Error>
      do {
        result = .success(
          try await client.transcribe(
            audioURL: job.audioURL,
            provider: job.provider,
            apiKey: job.apiKey
          ))
      } catch {
        result = .failure(error)
      }
      jobs.removeFirst()
      await completion(job, result)
      notifyDepth()
    }
    isProcessing = false
  }

  private func notifyDepth() {
    let count = jobs.count
    Task { @MainActor [depthChanged] in depthChanged(count) }
  }
}
