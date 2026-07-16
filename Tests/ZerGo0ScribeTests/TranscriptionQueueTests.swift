import Foundation
import XCTest

@testable import ZerGo0Scribe

@MainActor
final class TranscriptionQueueTests: XCTestCase {
  func testQueueProcessesSeriallyAndContinuesAfterFailure() async throws {
    let client = QueueTestClient()
    let completed = expectation(description: "All jobs complete")
    completed.expectedFulfillmentCount = 3
    var results: [String] = []
    let queue = TranscriptionQueue(
      client: client,
      completion: { job, result in
        switch result {
        case .success(let text): results.append(text)
        case .failure: results.append("failed:\(job.audioURL.lastPathComponent)")
        }
        completed.fulfill()
      },
      depthChanged: { _ in }
    )
    let provider = ProviderConfiguration.default

    await queue.enqueue(
      .init(
        audioURL: URL(fileURLWithPath: "/tmp/one"), duration: 1, provider: provider, apiKey: "k"))
    await queue.enqueue(
      .init(
        audioURL: URL(fileURLWithPath: "/tmp/fail"), duration: 1, provider: provider, apiKey: "k"))
    await queue.enqueue(
      .init(
        audioURL: URL(fileURLWithPath: "/tmp/three"), duration: 1, provider: provider, apiKey: "k"))

    await fulfillment(of: [completed], timeout: 2)
    XCTAssertEqual(results, ["one", "failed:fail", "three"])
    let state = await client.state()
    XCTAssertEqual(state.calls, ["one", "fail", "three"])
    XCTAssertEqual(state.maximumActive, 1)
    let pendingCount = await queue.pendingCount()
    XCTAssertEqual(pendingCount, 0)
  }
}

private actor QueueTestClient: Transcribing {
  private var calls: [String] = []
  private var active = 0
  private var maximumActive = 0

  func transcribe(
    audioURL: URL,
    provider: ProviderConfiguration,
    apiKey: String
  ) async throws -> String {
    let name = audioURL.lastPathComponent
    calls.append(name)
    active += 1
    maximumActive = max(maximumActive, active)
    try await Task.sleep(for: .milliseconds(20))
    active -= 1
    if name == "fail" { throw DictationError.requestFailed("expected") }
    return name
  }

  func state() -> (calls: [String], maximumActive: Int) { (calls, maximumActive) }
}
