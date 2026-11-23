import AVFoundation
import Foundation

@MainActor
final class AudioRecorder {
  struct Recording: Sendable {
    let url: URL
    let duration: TimeInterval
    let warning: InputWarning?
  }

  private static let tapBufferFrames: AVAudioFrameCount = 4_096
  private static let trailingCapture = Duration.milliseconds(300)

  private let sink = RecordingSink()
  private var engine: AVAudioEngine?
  private var tapFormat: AVAudioFormat?
  private var configurationObserver: NSObjectProtocol?
  private var configurationChangedWhileRecording = false
  private var usesBluetooth = false

  var isRecording: Bool { sink.isActive }

  func prepareIfAuthorized() {
    guard PermissionManager.microphoneGranted, !InputDevice.defaultIsBluetooth else { return }
    _ = try? readyEngine()
  }

  func start() async throws -> Date {
    guard await PermissionManager.requestMicrophone() else { throw DictationError.microphoneDenied }

    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("ScribeRecordings", isDirectory: true)
    let url = directory.appendingPathComponent("\(UUID().uuidString).wav")

    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let engine = try readyEngine()
      guard let tapFormat else { throw DictationError.recordingFailed("No microphone is available.") }
      sink.begin(try RecordingWriter(url: url, inputFormat: tapFormat))
      usesBluetooth = InputDevice.defaultIsBluetooth
      configurationChangedWhileRecording = false
      do {
        try engine.start()
      } catch {
        sink.end()?.discard()
        tearDown()
        throw error
      }
      return Date()
    } catch let error as DictationError {
      throw error
    } catch {
      throw DictationError.recordingFailed(error.localizedDescription)
    }
  }

  func stop() async throws -> Recording {
    guard sink.isActive else {
      throw DictationError.recordingFailed("There is no active recording.")
    }
    try? await Task.sleep(for: Self.trailingCapture)
    engine?.stop()
    guard let writer = sink.end() else {
      throw DictationError.recordingFailed("There is no active recording.")
    }
    defer { keepReadyOrTearDown() }

    let result: RecordingWriter.Result
    do {
      result = try writer.finish()
    } catch {
      writer.discard()
      throw DictationError.recordingFailed(error.localizedDescription)
    }
    return Recording(
      url: result.url,
      duration: result.duration,
      warning: InputWarning(level: result.level, usesBluetooth: usesBluetooth)
    )
  }

  func cancel() {
    engine?.stop()
    sink.end()?.discard()
    keepReadyOrTearDown()
  }

  private func readyEngine() throws -> AVAudioEngine {
    if let engine, let tapFormat, engine.inputNode.outputFormat(forBus: 0) == tapFormat {
      return engine
    }
    tearDown()

    let engine = AVAudioEngine()
    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    guard format.sampleRate > 0, format.channelCount > 0 else {
      throw DictationError.recordingFailed("No microphone is available.")
    }
    sink.installTap(on: input, bufferSize: Self.tapBufferFrames, format: format)
    engine.prepare()
    configurationObserver = NotificationCenter.default.addObserver(
      forName: .AVAudioEngineConfigurationChange,
      object: engine,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.configurationChanged() }
    }
    self.engine = engine
    tapFormat = format
    return engine
  }

  private func configurationChanged() {
    if sink.isActive {
      configurationChangedWhileRecording = true
    } else {
      tearDown()
      prepareIfAuthorized()
    }
  }

  private func keepReadyOrTearDown() {
    if configurationChangedWhileRecording || InputDevice.defaultIsBluetooth {
      tearDown()
      prepareIfAuthorized()
    } else {
      engine?.prepare()
    }
  }

  private func tearDown() {
    if let configurationObserver {
      NotificationCenter.default.removeObserver(configurationObserver)
    }
    configurationObserver = nil
    engine?.stop()
    engine?.inputNode.removeTap(onBus: 0)
    engine = nil
    tapFormat = nil
  }
}
