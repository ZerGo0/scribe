import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
  case general
  case transcription
  case vocabulary
  case cleanup

  var id: Self { self }

  var title: String {
    switch self {
    case .general: "General"
    case .transcription: "Transcription"
    case .vocabulary: "Names and Terms"
    case .cleanup: "Cleanup"
    }
  }

  var systemImage: String {
    switch self {
    case .general: "gearshape"
    case .transcription: "waveform"
    case .vocabulary: "character.book.closed"
    case .cleanup: "wand.and.stars"
    }
  }
}

struct SettingsView: View {
  @ObservedObject var controller: AppController
  @State private var selection = SettingsPane.general

  var body: some View {
    TabView(selection: $selection) {
      ForEach(SettingsPane.allCases) { pane in
        content(for: pane)
          .tabItem { Label(pane.title, systemImage: pane.systemImage) }
          .tag(pane)
      }
    }
    .frame(width: 600, height: 560)
  }

  @ViewBuilder
  private func content(for pane: SettingsPane) -> some View {
    switch pane {
    case .general:
      GeneralSettingsPane(controller: controller, settings: controller.settings)
    case .transcription:
      TranscriptionSettingsPane(controller: controller, settings: controller.settings)
    case .vocabulary:
      VocabularySettingsPane(settings: controller.settings)
    case .cleanup:
      CleanupSettingsPane(settings: controller.settings)
    }
  }
}
