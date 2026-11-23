import AppKit
import SwiftUI

struct MenuBarContent: View {
  @ObservedObject var controller: AppController
  @ObservedObject var history: HistoryStore
  @Environment(\.openSettings) private var openSettings
  @Environment(\.openWindow) private var openWindow

  private let recentCount = 5
  private let previewLength = 48

  var body: some View {
    Button(controller.isRecording ? "Stop Dictation" : "Start Dictation") {
      controller.toggleDictation()
    }
    Text("Shortcut: \(GlobalHotKey.displayName(for: controller.settings.hotKey))")

    if controller.queuedCount > 0 {
      Text(
        controller.queuedCount == 1
          ? "Transcribing…" : "Transcribing \(controller.queuedCount) dictations…"
      )
    }

    if let error = controller.lastError {
      Divider()
      Label(error, systemImage: "exclamationmark.triangle")
    }

    if !history.transcripts.isEmpty {
      Divider()
      Section("Click to Copy") {
        ForEach(history.transcripts.prefix(recentCount)) { transcript in
          Button(preview(transcript.text)) { ClipboardInserter.copy(transcript.text) }
        }
      }
    }

    Divider()
    Button("History…") {
      openWindow(id: "history")
      NSApplication.shared.activate()
    }
    .keyboardShortcut("y")
    Button("Settings…") {
      openSettings()
      NSApplication.shared.activate()
    }
    .keyboardShortcut(",")

    Divider()
    Button("Quit Scribe") { NSApplication.shared.terminate(nil) }
      .keyboardShortcut("q")
  }

  private func preview(_ text: String) -> String {
    let line = text.split(whereSeparator: \.isNewline).joined(separator: " ")
    return line.count > previewLength ? "\(line.prefix(previewLength))…" : line
  }
}
