import AppKit
import SwiftUI

struct HotKeyRecorderView: NSViewRepresentable {
  let configuration: HotKeyConfiguration
  let onChange: (HotKeyConfiguration) -> Void

  func makeNSView(context: Context) -> CaptureButton {
    let button = CaptureButton()
    button.onCapture = { value in
      onChange(value)
    }
    button.configuration = configuration
    return button
  }

  func updateNSView(_ button: CaptureButton, context: Context) {
    button.configuration = configuration
    button.onCapture = { value in
      onChange(value)
    }
  }
}

@MainActor
final class CaptureButton: NSButton {
  var onCapture: ((HotKeyConfiguration) -> Void)?
  var configuration: HotKeyConfiguration = .default {
    didSet { if !capturing { title = GlobalHotKey.displayName(for: configuration) } }
  }
  private var capturing = false

  init() {
    super.init(frame: .zero)
    bezelStyle = .rounded
    setButtonType(.momentaryPushIn)
    target = self
    action = #selector(beginCapture)
    toolTip = "Click, then press a modified shortcut or a standalone function key."
    setAccessibilityLabel("Dictation shortcut")
  }

  required init?(coder: NSCoder) { nil }

  override var acceptsFirstResponder: Bool { true }

  @objc private func beginCapture() {
    capturing = true
    title = "Press shortcut…"
    window?.makeFirstResponder(self)
  }

  override func keyDown(with event: NSEvent) {
    if event.keyCode == 53 {
      capturing = false
      title = GlobalHotKey.displayName(for: configuration)
      return
    }
    guard capturing, let value = GlobalHotKey.configuration(from: event) else {
      NSSound.beep()
      return
    }
    capturing = false
    configuration = value
    onCapture?(value)
    window?.makeFirstResponder(nil)
  }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    guard capturing else { return super.performKeyEquivalent(with: event) }
    keyDown(with: event)
    return true
  }
}
