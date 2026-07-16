import AppKit
import Carbon
import Foundation

@MainActor
final class GlobalHotKey {
  private var hotKeyRef: EventHotKeyRef?
  private var eventHandler: EventHandlerRef?
  private var action: (() -> Void)?

  init() {
    var eventType = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed)
    )
    InstallEventHandler(
      GetApplicationEventTarget(),
      Self.eventHandlerCallback,
      1,
      &eventType,
      Unmanaged.passUnretained(self).toOpaque(),
      &eventHandler
    )
  }

  isolated deinit {
    if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
    if let eventHandler { RemoveEventHandler(eventHandler) }
  }

  func register(_ configuration: HotKeyConfiguration, action: @escaping () -> Void) throws {
    if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
    self.action = action
    let identifier = EventHotKeyID(signature: Self.signature, id: 1)
    let status = RegisterEventHotKey(
      configuration.keyCode,
      configuration.carbonModifiers,
      identifier,
      GetApplicationEventTarget(),
      0,
      &hotKeyRef
    )
    guard status == noErr else {
      throw NSError(
        domain: NSOSStatusErrorDomain,
        code: Int(status),
        userInfo: [NSLocalizedDescriptionKey: "That shortcut is unavailable."]
      )
    }
  }

  static func displayName(for configuration: HotKeyConfiguration) -> String {
    var parts: [String] = []
    let modifiers = configuration.carbonModifiers
    if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
    if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
    if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
    if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
    parts.append(keyName(for: configuration.keyCode))
    return parts.joined()
  }

  static func configuration(from event: NSEvent) -> HotKeyConfiguration? {
    configuration(keyCode: event.keyCode, modifierFlags: event.modifierFlags)
  }

  static func configuration(
    keyCode: UInt16,
    modifierFlags: NSEvent.ModifierFlags
  ) -> HotKeyConfiguration? {
    let relevant = modifierFlags.intersection([.command, .option, .control, .shift])
    guard !relevant.isEmpty || functionKeyCodes.contains(UInt32(keyCode)) else { return nil }
    var carbonModifiers: UInt32 = 0
    if relevant.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
    if relevant.contains(.option) { carbonModifiers |= UInt32(optionKey) }
    if relevant.contains(.control) { carbonModifiers |= UInt32(controlKey) }
    if relevant.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
    return HotKeyConfiguration(keyCode: UInt32(keyCode), carbonModifiers: carbonModifiers)
  }

  private static let signature: OSType = 0x5A53_4352  // ZSCR

  private static let functionKeyCodes: Set<UInt32> = [
    UInt32(kVK_F1), UInt32(kVK_F2), UInt32(kVK_F3), UInt32(kVK_F4),
    UInt32(kVK_F5), UInt32(kVK_F6), UInt32(kVK_F7), UInt32(kVK_F8),
    UInt32(kVK_F9), UInt32(kVK_F10), UInt32(kVK_F11), UInt32(kVK_F12),
    UInt32(kVK_F13), UInt32(kVK_F14), UInt32(kVK_F15), UInt32(kVK_F16),
    UInt32(kVK_F17), UInt32(kVK_F18), UInt32(kVK_F19), UInt32(kVK_F20),
  ]

  private static let eventHandlerCallback: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var identifier = EventHotKeyID()
    let status = GetEventParameter(
      event,
      EventParamName(kEventParamDirectObject),
      EventParamType(typeEventHotKeyID),
      nil,
      MemoryLayout<EventHotKeyID>.size,
      nil,
      &identifier
    )
    guard status == noErr, identifier.signature == signature else { return status }
    let instance = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
    MainActor.assumeIsolated { instance.action?() }
    return noErr
  }

  private static func keyName(for keyCode: UInt32) -> String {
    let names: [UInt32: String] = [
      UInt32(kVK_Space): "Space", UInt32(kVK_Return): "Return",
      UInt32(kVK_Tab): "Tab", UInt32(kVK_Escape): "Esc",
      UInt32(kVK_Delete): "Delete", UInt32(kVK_ForwardDelete): "Forward Delete",
      UInt32(kVK_LeftArrow): "←", UInt32(kVK_RightArrow): "→",
      UInt32(kVK_UpArrow): "↑", UInt32(kVK_DownArrow): "↓",
      UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2", UInt32(kVK_F3): "F3",
      UInt32(kVK_F4): "F4", UInt32(kVK_F5): "F5", UInt32(kVK_F6): "F6",
      UInt32(kVK_F7): "F7", UInt32(kVK_F8): "F8", UInt32(kVK_F9): "F9",
      UInt32(kVK_F10): "F10", UInt32(kVK_F11): "F11", UInt32(kVK_F12): "F12",
      UInt32(kVK_F13): "F13", UInt32(kVK_F14): "F14", UInt32(kVK_F15): "F15",
      UInt32(kVK_F16): "F16", UInt32(kVK_F17): "F17", UInt32(kVK_F18): "F18",
      UInt32(kVK_F19): "F19", UInt32(kVK_F20): "F20",
    ]
    if let name = names[keyCode] { return name }

    let letterKeyCodes: [UInt32: String] = [
      0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G",
      4: "H", 34: "I", 38: "J", 40: "K", 37: "L", 46: "M", 45: "N",
      31: "O", 35: "P", 12: "Q", 15: "R", 1: "S", 17: "T", 32: "U",
      9: "V", 13: "W", 7: "X", 16: "Y", 6: "Z",
    ]
    return letterKeyCodes[keyCode] ?? "Key \(keyCode)"
  }
}
