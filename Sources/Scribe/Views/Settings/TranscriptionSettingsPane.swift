import SwiftUI

struct TranscriptionSettingsPane: View {
  @ObservedObject var controller: AppController
  @ObservedObject var settings: AppSettings

  var body: some View {
    Form {
      Section {
        Picker("Transcribe with", selection: $settings.transcriptionProvider) {
          ForEach(TranscriptionProvider.allCases, id: \.self) { provider in
            Text(provider.displayName).tag(provider)
          }
        }
      } footer: {
        Text(settings.transcriptionProvider.detail)
      }

      switch settings.transcriptionProvider {
      case .localModel:
        LocalModelSettingsSection(settings: settings, library: controller.localModels)
      case .appleOnDevice:
        AppleSpeechSettingsSection(controller: controller, settings: settings)
      case .openAICompatible:
        RemoteProviderSettingsSection(controller: controller, settings: settings)
      }
    }
    .formStyle(.grouped)
  }
}
