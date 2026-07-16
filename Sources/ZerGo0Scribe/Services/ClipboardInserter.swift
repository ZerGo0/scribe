import AppKit
import CoreGraphics
import Foundation

@MainActor
final class ClipboardInserter {
  private struct ItemSnapshot {
    let values: [(NSPasteboard.PasteboardType, Data)]
  }

  private let pasteboard: NSPasteboard
  private let restoreDelay: Duration

  init(pasteboard: NSPasteboard = .general, restoreDelay: Duration = .milliseconds(250)) {
    self.pasteboard = pasteboard
    self.restoreDelay = restoreDelay
  }

  func insert(_ text: String) async throws {
    guard AXIsProcessTrusted() else { throw DictationError.accessibilityDenied }
    let snapshot = capture()
    let item = NSPasteboardItem()
    item.setString(text, forType: .string)
    item.setData(Data(), forType: .init("org.nspasteboard.TransientType"))
    item.setData(Data(), forType: .init("org.nspasteboard.ConcealedType"))
    item.setString("com.zergo0.zergo0scribe", forType: .init("org.nspasteboard.source"))
    pasteboard.clearContents()
    pasteboard.writeObjects([item])
    let transcriptChangeCount = pasteboard.changeCount

    guard let source = CGEventSource(stateID: .hidSystemState),
      let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
      let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
    else {
      restore(snapshot)
      throw DictationError.accessibilityDenied
    }
    keyDown.flags = .maskCommand
    keyUp.flags = .maskCommand
    keyDown.post(tap: .cghidEventTap)
    keyUp.post(tap: .cghidEventTap)

    try? await Task.sleep(for: restoreDelay)
    if pasteboard.changeCount == transcriptChangeCount {
      restore(snapshot)
    }
  }

  private func capture() -> [ItemSnapshot] {
    (pasteboard.pasteboardItems ?? []).map { item in
      let values = item.types.compactMap { type in
        item.data(forType: type).map { (type, $0) }
      }
      return ItemSnapshot(values: values)
    }
  }

  private func restore(_ snapshot: [ItemSnapshot]) {
    pasteboard.clearContents()
    guard !snapshot.isEmpty else { return }
    let items = snapshot.map { saved in
      let item = NSPasteboardItem()
      for (type, data) in saved.values { item.setData(data, forType: type) }
      return item
    }
    pasteboard.writeObjects(items)
  }
}
