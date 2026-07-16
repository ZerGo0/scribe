import AVFoundation
import AppKit
import ServiceManagement

@MainActor
enum PermissionManager {
  static var microphoneGranted: Bool {
    AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
  }

  static var accessibilityGranted: Bool { AXIsProcessTrusted() }

  static func requestMicrophone() async -> Bool {
    await AVCaptureDevice.requestAccess(for: .audio)
  }

  static func requestAccessibility() {
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    AXIsProcessTrustedWithOptions(options)
  }
}

@MainActor
enum LaunchAtLoginManager {
  static func setEnabled(_ enabled: Bool) throws {
    if enabled {
      if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
    } else if SMAppService.mainApp.status == .enabled {
      try SMAppService.mainApp.unregister()
    }
  }
}

@MainActor
final class SoundFeedback {
  enum Event { case started, completed, failed }

  func play(_ event: Event) {
    let name: NSSound.Name =
      switch event {
      case .started: .init("Tink")
      case .completed: .init("Pop")
      case .failed: .init("Basso")
      }
    NSSound(named: name)?.play()
  }
}
