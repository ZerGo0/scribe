import SwiftUI

@main
struct ScribeApp: App {
  @StateObject private var controller = AppController()

  var body: some Scene {
    MenuBarExtra {
      MenuBarContent(controller: controller, history: controller.history)
    } label: {
      Label(
        "Scribe",
        systemImage: controller.isRecording ? "mic.fill" : "waveform"
      )
    }
    .menuBarExtraStyle(.menu)

    Settings {
      SettingsView(controller: controller)
    }

    Window("Dictation History", id: "history") {
      HistoryView(history: controller.history)
    }
    .defaultSize(width: 620, height: 460)
  }
}
