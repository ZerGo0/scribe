import SwiftUI

struct RemoteProviderSettingsSection: View {
  @ObservedObject var controller: AppController
  @ObservedObject var settings: AppSettings
  @State private var apiKey = ""
  @State private var models: [String] = []
  @State private var isLoadingModels = false
  @State private var modelMessage: String?
  @State private var modelMessageIsError = false

  var body: some View {
    Section {
      TextField(
        "Base URL",
        text: $settings.provider.baseURL,
        prompt: Text(ProviderConfiguration.default.baseURL)
      )
      SecureField("API key", text: $apiKey, prompt: Text("Required"))
        .onChange(of: apiKey) { _, value in controller.saveAPIKey(value) }
    } header: {
      Text("Connection")
    } footer: {
      if hasInvalidURL {
        Label("Enter a URL that starts with https:// or http://.", systemImage: "exclamationmark.circle")
          .foregroundStyle(.red)
      } else {
        Text("Scribe saves the API key in your Keychain.")
      }
    }
    .onChange(of: settings.provider.baseURL) { _, _ in
      models = []
      modelMessage = nil
    }

    Section {
      TextField(
        "Model",
        text: $settings.provider.model,
        prompt: Text(ProviderConfiguration.default.model)
      )
      if !models.isEmpty {
        Picker("Available models", selection: $settings.provider.model) {
          if !models.contains(settings.provider.model) {
            Text(settings.provider.model).tag(settings.provider.model)
          }
          ForEach(models, id: \.self) { model in
            Text(model).tag(model)
          }
        }
      }
      LabeledContent {
        HStack(spacing: 8) {
          if isLoadingModels {
            ProgressView().controlSize(.small)
          }
          Button("Load Models", action: loadModels)
            .disabled(isLoadingModels || !canLoadModels)
        }
      } label: {
        Text("Models from provider")
        Text("Lists the models that this provider offers.")
      }
    } header: {
      Text("Model")
    } footer: {
      if let modelMessage {
        Text(modelMessage)
          .foregroundStyle(modelMessageIsError ? Color.red : Color.secondary)
      }
    }
    .onAppear { apiKey = controller.apiKey() }
  }

  private var hasInvalidURL: Bool {
    !settings.provider.baseURL.trimmingCharacters(in: .whitespaces).isEmpty
      && settings.provider.normalizedBaseURL == nil
  }

  private var canLoadModels: Bool {
    settings.provider.normalizedBaseURL != nil
      && !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private func loadModels() {
    isLoadingModels = true
    modelMessage = nil
    Task {
      do {
        models = try await controller.fetchModels(apiKey: apiKey)
        modelMessage =
          models.isEmpty
          ? "The provider listed no models. Enter a model name above."
          : "Found \(models.count) models."
        modelMessageIsError = models.isEmpty
      } catch {
        modelMessage = error.localizedDescription
        modelMessageIsError = true
      }
      isLoadingModels = false
    }
  }
}
