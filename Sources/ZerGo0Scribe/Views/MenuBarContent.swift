import AppKit
import SwiftUI

struct MenuBarContent: View {
  @ObservedObject var controller: AppController
  @ObservedObject var history: HistoryStore
  @Environment(\.openSettings) private var openSettings
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    Button(controller.isRecording ? "Stop Dictation" : "Start Dictation") {
      controller.toggleDictation()
    }
    .keyboardShortcut("d")

    if controller.queuedCount > 0 {
      Text("\(controller.queuedCount) dictation\(controller.queuedCount == 1 ? "" : "s") queued")
    }

    Divider()

    Button("Copy Last Transcript") { controller.copyLastTranscript() }
      .disabled(history.lastTranscript == nil)

    Button("History…") { openWindow(id: "history") }
    Button("Settings…") { openSettings() }

    if let error = controller.lastError {
      Divider()
      Text(error)
    }

    Divider()
    Button("Quit ZerGo0Scribe") { NSApplication.shared.terminate(nil) }
      .keyboardShortcut("q")
  }
}
