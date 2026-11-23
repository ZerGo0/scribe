import AVFoundation
import Foundation

final class RecordingSink: @unchecked Sendable {
  private let lock = NSLock()
  private var writer: RecordingWriter?

  var isActive: Bool { lock.withLock { writer != nil } }

  func begin(_ writer: RecordingWriter) {
    lock.withLock { self.writer = writer }
  }

  func installTap(on node: AVAudioNode, bufferSize: AVAudioFrameCount, format: AVAudioFormat) {
    node.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [self] buffer, _ in
      lock.withLock { writer?.append(buffer) }
    }
  }

  @discardableResult
  func end() -> RecordingWriter? {
    lock.withLock {
      defer { writer = nil }
      return writer
    }
  }
}
