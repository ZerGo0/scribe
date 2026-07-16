import AppKit
import SwiftUI

struct SettingsView: View {
  @ObservedObject var controller: AppController
  @ObservedObject private var settings: AppSettings

  @State private var baseURL = ""
  @State private var apiKey = ""
  @State private var modelDraft = ""
  @State private var models: [String] = []
  @State private var modelSelection = Self.manualModelSelection
  @State private var isLoadingModels = false
  @State private var providerMessage: String?
  @State private var providerMessageIsError = false
  @State private var microphoneGranted = PermissionManager.microphoneGranted
  @State private var accessibilityGranted = PermissionManager.accessibilityGranted

  init(controller: AppController) {
    self.controller = controller
    settings = controller.settings
  }

  var body: some View {
    TabView {
      providerTab
        .tabItem { Label("Provider", systemImage: "server.rack") }
      generalTab
        .tabItem { Label("General", systemImage: "gearshape") }
    }
    .padding(20)
    .frame(width: 620, height: 460)
    .onAppear {
      baseURL = settings.provider.baseURL
      apiKey = controller.apiKey()
      modelDraft = settings.provider.model
      syncModelSelection()
      refreshPermissionState()
    }
    .onReceive(
      NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
    ) { _ in
      refreshPermissionState()
    }
    .task {
      while !Task.isCancelled && (!microphoneGranted || !accessibilityGranted) {
        refreshPermissionState()
        try? await Task.sleep(for: .seconds(1))
      }
    }
  }

  private var providerTab: some View {
    VStack(alignment: .leading, spacing: 20) {
      connectionGroup
      transcriptionGroup
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 8)
    .padding(.top, 8)
  }

  private var connectionGroup: some View {
    GroupBox("Connection") {
      Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
        GridRow {
          Text("Base URL")
          TextField(
            "Base URL",
            text: $baseURL,
            prompt: Text("https://api.openai.com/v1")
          )
          .labelsHidden()
          .textFieldStyle(.roundedBorder)
          .frame(maxWidth: .infinity)
          .onChange(of: baseURL) { _, _ in
            models = []
            providerMessage = nil
            syncModelSelection()
          }
        }

        Divider().gridCellColumns(2)

        GridRow {
          Text("API key")
          SecureField("API key", text: $apiKey, prompt: Text("Required"))
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: .infinity)
        }

        Divider().gridCellColumns(2)

        HStack {
          Spacer()
          Button("Save") { saveConnection() }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!connectionIsValid)
        }
        .gridCellColumns(2)
      }
      .padding(4)
      .frame(maxWidth: .infinity)
    }
    .frame(maxWidth: .infinity)
  }

  private var transcriptionGroup: some View {
    GroupBox("Transcription") {
      Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
        GridRow {
          Text("Model")
          HStack(spacing: 8) {
            loadModelsButton
            modelMenu
            Spacer(minLength: 0)
          }
        }

        if modelSelection == Self.manualModelSelection {
          Divider().gridCellColumns(2)

          GridRow {
            Text("Model name")
            TextField("Model name", text: $modelDraft)
              .labelsHidden()
              .textFieldStyle(.roundedBorder)
              .frame(maxWidth: .infinity)
          }
        }

        if let providerMessage {
          Divider().gridCellColumns(2)

          Label(
            providerMessage,
            systemImage: providerMessageIsError ? "exclamationmark.circle" : "info.circle"
          )
          .font(.callout)
          .foregroundStyle(providerMessageIsError ? Color.red : Color.secondary)
          .gridCellColumns(2)
        }

        Divider().gridCellColumns(2)

        HStack {
          Spacer()
          Button("Save") { saveTranscription() }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(modelDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .gridCellColumns(2)
      }
      .padding(4)
      .frame(maxWidth: .infinity)
    }
    .frame(maxWidth: .infinity)
  }

  private var loadModelsButton: some View {
    Button {
      loadModels()
    } label: {
      if isLoadingModels {
        HStack(spacing: 5) {
          ProgressView().controlSize(.small)
          Text("Loading…")
        }
      } else {
        Label("Load models", systemImage: "arrow.clockwise")
      }
    }
    .buttonStyle(.bordered)
    .controlSize(.small)
    .disabled(isLoadingModels || !connectionIsValid)
  }

  private var modelMenu: some View {
    Menu {
      ForEach(models, id: \.self) { model in
        Button(model) {
          modelSelection = model
          modelDraft = model
        }
      }

      if !models.isEmpty { Divider() }

      Button("Manual entry…") {
        modelSelection = Self.manualModelSelection
      }
    } label: {
      Text(selectedModelName)
        .lineLimit(1)
        .frame(width: 190, alignment: .leading)
    }
    .menuStyle(.button)
    .buttonStyle(.bordered)
    .controlSize(.small)
    .accessibilityLabel("Model")
  }

  private var generalTab: some View {
    VStack(alignment: .leading, spacing: 20) {
      GroupBox("Dictation") {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
          GridRow {
            Text("Shortcut")
            HStack {
              HotKeyRecorderView(
                configuration: settings.hotKey,
                onChange: controller.updateHotKey
              )
              .frame(width: 150, height: 28)
              Spacer(minLength: 0)
            }
          }

          Divider().gridCellColumns(2)

          GridRow {
            Text("Launch at login")
            HStack {
              Toggle(
                "Launch at login",
                isOn: Binding(
                  get: { settings.launchAtLogin },
                  set: controller.setLaunchAtLogin
                )
              )
              .labelsHidden()
              Spacer(minLength: 0)
            }
          }
        }
        .padding(4)
        .frame(maxWidth: .infinity)
      }
      .frame(maxWidth: .infinity)

      GroupBox("Permissions") {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
          GridRow {
            Text("Microphone")
            permissionControls(granted: microphoneGranted, actionTitle: "Request Access") {
              Task {
                _ = await PermissionManager.requestMicrophone()
                refreshPermissionState()
              }
            }
          }

          Divider().gridCellColumns(2)

          GridRow {
            Text("Accessibility")
            permissionControls(granted: accessibilityGranted, actionTitle: "Open Prompt") {
              PermissionManager.requestAccessibility()
              refreshPermissionState()
            }
          }
        }
        .padding(4)
        .frame(maxWidth: .infinity)
      }
      .frame(maxWidth: .infinity)

      if let error = controller.lastError {
        GroupBox("Last error") {
          Text(error)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        }
        .frame(maxWidth: .infinity)
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 8)
    .padding(.top, 8)
  }

  private func permissionControls(
    granted: Bool,
    actionTitle: String,
    action: @escaping () -> Void
  ) -> some View {
    HStack(spacing: 10) {
      Text(granted ? "Granted" : "Required")
        .foregroundStyle(granted ? Color.secondary : Color.red)
      if !granted {
        Button(actionTitle, action: action)
          .buttonStyle(.bordered)
          .controlSize(.small)
      }
      Spacer(minLength: 0)
    }
  }

  private var connectionIsValid: Bool {
    let provider = ProviderConfiguration(baseURL: baseURL, model: modelDraft)
    return provider.normalizedBaseURL != nil
      && !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var selectedModelName: String {
    if modelSelection == Self.manualModelSelection {
      let trimmed = modelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? "Manual entry…" : trimmed
    }
    return modelSelection
  }

  private func saveConnection() {
    settings.provider.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    controller.saveAPIKey(apiKey)
  }

  private func saveTranscription() {
    settings.provider.model = modelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func loadModels() {
    saveConnection()
    isLoadingModels = true
    providerMessage = nil
    Task {
      do {
        models = try await controller.fetchModels(apiKey: apiKey)
        syncModelSelection()
        providerMessage =
          models.isEmpty
          ? "No models found. You can enter one manually." : "Loaded \(models.count) models."
        providerMessageIsError = models.isEmpty
      } catch {
        providerMessage = error.localizedDescription
        providerMessageIsError = true
      }
      isLoadingModels = false
    }
  }

  private func refreshPermissionState() {
    microphoneGranted = PermissionManager.microphoneGranted
    accessibilityGranted = PermissionManager.accessibilityGranted
    if accessibilityGranted
      && controller.lastError == DictationError.accessibilityDenied.localizedDescription
    {
      controller.lastError = nil
    }
  }

  private func syncModelSelection() {
    modelSelection =
      models.contains(modelDraft)
      ? modelDraft
      : Self.manualModelSelection
  }

  private static let manualModelSelection = "__zergo0scribe_manual_model__"
}
