import AppKit
import SwiftUI

@MainActor
final class RecordingPillController {
  private var panel: NSPanel?

  func show(startedAt: Date, on targetScreen: NSScreen?) {
    if panel == nil {
      let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 96, height: 44),
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
      )
      panel.isOpaque = false
      panel.backgroundColor = .clear
      panel.hasShadow = true
      panel.level = .floating
      panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
      panel.hidesOnDeactivate = false
      self.panel = panel
    }
    panel?.contentView = NSHostingView(rootView: RecordingPillView(startedAt: startedAt))
    positionPanel(on: targetScreen)
    panel?.orderFrontRegardless()
  }

  func hide() {
    panel?.orderOut(nil)
  }

  private func positionPanel(on targetScreen: NSScreen?) {
    guard let panel, let screen = targetScreen ?? NSScreen.main else { return }
    let visible = screen.visibleFrame
    let x = visible.midX - panel.frame.width / 2
    let y = visible.minY + 36
    panel.setFrameOrigin(NSPoint(x: x, y: y))
  }
}

private struct RecordingPillView: View {
  let startedAt: Date

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      HStack(spacing: 8) {
        Circle()
          .fill(.red)
          .frame(width: 8, height: 8)
          .accessibilityHidden(true)
        Text(elapsed(at: context.date))
          .font(.system(.body, design: .monospaced, weight: .medium))
          .monospacedDigit()
      }
      .padding(.horizontal, 14)
      .frame(height: 40)
      .background(.ultraThickMaterial, in: Capsule())
      .overlay { Capsule().stroke(.primary.opacity(0.12), lineWidth: 1) }
    }
    .frame(width: 96, height: 44)
  }

  private func elapsed(at date: Date) -> String {
    let seconds = max(0, Int(date.timeIntervalSince(startedAt)))
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }
}
