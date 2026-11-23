import SwiftUI

struct AppleSpeechSettingsSection: View {
  @ObservedObject var controller: AppController
  @ObservedObject var settings: AppSettings
  @State private var localeIdentifiers: [String] = []
  @State private var isLoadingLocales = false

  var body: some View {
    Section {
      Picker("Mode", selection: $settings.appleSpeech.mode) {
        ForEach(AppleSpeechMode.allCases, id: \.self) { mode in
          Text(mode.displayName).tag(mode)
        }
      }
      LabeledContent("Language") {
        HStack(spacing: 8) {
          if isLoadingLocales {
            ProgressView().controlSize(.small)
          }
          Picker("Language", selection: $settings.appleSpeech.localeIdentifier) {
            ForEach(localeIdentifiers, id: \.self) { identifier in
              Text(localeDisplayName(identifier)).tag(identifier)
            }
          }
          .labelsHidden()
          .fixedSize()
        }
      }
    } header: {
      Text("Apple Speech")
    } footer: {
      Text("\(settings.appleSpeech.mode.detail) Language files download automatically.")
    }
    .task(id: settings.appleSpeech.mode) { await loadLocales() }
  }

  private func loadLocales() async {
    let mode = settings.appleSpeech.mode
    isLoadingLocales = true
    var identifiers = await controller.appleSpeechLocaleIdentifiers(for: mode)
    guard settings.appleSpeech.mode == mode else { return }
    let selected = settings.appleSpeech.normalizedLocaleIdentifier
      .replacingOccurrences(of: "_", with: "-")
    if !identifiers.contains(selected) {
      identifiers.insert(selected, at: 0)
    }
    localeIdentifiers = identifiers
    if settings.appleSpeech.localeIdentifier != selected {
      settings.appleSpeech.localeIdentifier = selected
    }
    isLoadingLocales = false
  }

  private func localeDisplayName(_ identifier: String) -> String {
    Locale.current.localizedString(forIdentifier: identifier) ?? identifier
  }
}
