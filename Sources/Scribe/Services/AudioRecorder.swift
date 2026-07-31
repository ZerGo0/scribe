import AVFoundation
import Foundation

@MainActor
final class AudioRecorder {
  struct Recording: Sendable {
    let url: URL
    let duration: TimeInterval
  }

  private var recorder: AVAudioRecorder?
  private var startedAt: Date?

  var isRecording: Bool { recorder?.isRecording == true }

  func start() async throws -> Date {
    let allowed = await AVCaptureDevice.requestAccess(for: .audio)
    guard allowed else { throw DictationError.microphoneDenied }

    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("ScribeRecordings", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("\(UUID().uuidString).wav")
    let settings: [String: Any] = [
      AVFormatIDKey: Int(kAudioFormatLinearPCM),
      AVSampleRateKey: 16_000,
      AVNumberOfChannelsKey: 1,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsFloatKey: false,
    ]

    do {
      let recorder = try AVAudioRecorder(url: url, settings: settings)
      recorder.prepareToRecord()
      guard recorder.record() else {
        throw DictationError.recordingFailed("The microphone could not start.")
      }
      let start = Date()
      self.recorder = recorder
      startedAt = start
      return start
    } catch let error as DictationError {
      throw error
    } catch {
      throw DictationError.recordingFailed(error.localizedDescription)
    }
  }

  func stop() throws -> Recording {
    guard let recorder, let startedAt else {
      throw DictationError.recordingFailed("There is no active recording.")
    }
    recorder.stop()
    self.recorder = nil
    self.startedAt = nil
    return Recording(url: recorder.url, duration: max(0, Date().timeIntervalSince(startedAt)))
  }

  func cancel() {
    recorder?.stop()
    if let url = recorder?.url { try? FileManager.default.removeItem(at: url) }
    recorder = nil
    startedAt = nil
  }
}
