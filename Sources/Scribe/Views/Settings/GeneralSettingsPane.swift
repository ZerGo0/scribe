import AppKit
import SwiftUI

struct GeneralSettingsPane: View {
  @ObservedObject var controller: AppController
  @ObservedObject var settings: AppSettings
  @State private var microphoneGranted = PermissionManager.microphoneGranted
  @State private var speechRecognitionGranted = PermissionManager.speechRecognitionGranted
  @State private var accessibilityGranted = PermissionManager.accessibilityGranted

  var body: some View {
    Form {
      if let error = controller.lastError {
        Section {
          HStack(alignment: .firstTextBaseline, spacing: 12) {
            Label(error, systemImage: "exclamationmark.triangle.fill")
              .foregroundStyle(.red)
              .frame(maxWidth: .infinity, alignment: .leading)
            Button("Dismiss") { controller.lastError = nil }
          }
        }
      }

      Section("Dictation") {
        LabeledContent {
          HotKeyRecorderView(configuration: settings.hotKey, onChange: controller.updateHotKey)
            .frame(width: 150, height: 24)
        } label: {
          Text("Shortcut")
          Text("Press it once to start recording and again to stop.")
        }
        Toggle(
          "Launch at login",
          isOn: Binding(get: { settings.launchAtLogin }, set: controller.setLaunchAtLogin)
        )
      }

      Section("Permissions") {
        permissionRow(
          "Microphone",
          detail: "Records your voice while you dictate.",
          granted: microphoneGranted
        ) {
          Task {
            _ = await PermissionManager.requestMicrophone()
            refreshPermissions()
          }
        }
        if settings.transcriptionProvider == .appleOnDevice {
          permissionRow(
            "Speech Recognition",
            detail: "Lets Apple Speech transcribe your recordings.",
            granted: speechRecognitionGranted
          ) {
            Task {
              _ = await PermissionManager.requestSpeechRecognition()
              refreshPermissions()
            }
          }
        }
        permissionRow(
          "Accessibility",
          detail: "Pastes the text into the app you are using.",
          granted: accessibilityGranted
        ) {
          PermissionManager.requestAccessibility()
          refreshPermissions()
        }
      }
    }
    .formStyle(.grouped)
    .onAppear(perform: refreshPermissions)
    .onReceive(
      NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
    ) { _ in
      refreshPermissions()
    }
    .task {
      while !Task.isCancelled && !allPermissionsGranted {
        try? await Task.sleep(for: .seconds(1))
        refreshPermissions()
      }
    }
  }

  private var allPermissionsGranted: Bool {
    microphoneGranted && accessibilityGranted
      && (settings.transcriptionProvider != .appleOnDevice || speechRecognitionGranted)
  }

  private func permissionRow(
    _ title: String,
    detail: String,
    granted: Bool,
    action: @escaping () -> Void
  ) -> some View {
    LabeledContent {
      if granted {
        Label("Allowed", systemImage: "checkmark.circle.fill")
          .foregroundStyle(.green)
      } else {
        Button("Allow…", action: action)
      }
    } label: {
      Text(title)
      Text(detail)
    }
  }

  private func refreshPermissions() {
    microphoneGranted = PermissionManager.microphoneGranted
    speechRecognitionGranted = PermissionManager.speechRecognitionGranted
    accessibilityGranted = PermissionManager.accessibilityGranted
    if accessibilityGranted
      && controller.lastError == DictationError.accessibilityDenied.localizedDescription
    {
      controller.lastError = nil
    }
  }
}
