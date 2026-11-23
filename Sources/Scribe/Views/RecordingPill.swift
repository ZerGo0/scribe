import AppKit
import SwiftUI

enum RecordingPillState {
  case recording(startedAt: Date)
  case transcribing
}

@MainActor
final class RecordingPillController {
  private var panel: NSPanel?
  private var screen: NSScreen?
  private let bottomMargin: CGFloat = 36

  func show(_ state: RecordingPillState, on targetScreen: NSScreen?) {
    let panel = self.panel ?? makePanel()
    self.panel = panel
    if let targetScreen { screen = targetScreen }
    let host = NSHostingView(rootView: RecordingPillView(state: state))
    let size = host.fittingSize
    host.frame = NSRect(origin: .zero, size: size)
    panel.setContentSize(size)
    panel.contentView = host
    position(panel)
    panel.orderFrontRegardless()
  }

  func hide() {
    panel?.orderOut(nil)
  }

  private func makePanel() -> NSPanel {
    let panel = NSPanel(
      contentRect: .zero,
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
    return panel
  }

  private func position(_ panel: NSPanel) {
    guard let visible = (screen ?? NSScreen.main)?.visibleFrame else { return }
    panel.setFrameOrigin(
      NSPoint(x: visible.midX - panel.frame.width / 2, y: visible.minY + bottomMargin)
    )
  }
}

private struct RecordingPillView: View {
  let state: RecordingPillState

  var body: some View {
    HStack(spacing: 8) {
      switch state {
      case .recording(let startedAt):
        Circle()
          .fill(.red)
          .frame(width: 8, height: 8)
          .accessibilityHidden(true)
        TimelineView(.periodic(from: .now, by: 1)) { context in
          Text(elapsed(since: startedAt, at: context.date))
            .font(.system(.body, design: .monospaced, weight: .medium))
            .monospacedDigit()
        }
        .accessibilityLabel("Recording")
      case .transcribing:
        ProgressView()
          .controlSize(.small)
        Text("Transcribing")
          .font(.body.weight(.medium))
      }
    }
    .padding(.horizontal, 14)
    .frame(minWidth: 88, minHeight: 36)
    .background(.regularMaterial, in: Capsule())
    .overlay { Capsule().strokeBorder(.primary.opacity(0.12)) }
    .padding(4)
    .fixedSize()
  }

  private func elapsed(since start: Date, at date: Date) -> String {
    let seconds = max(0, Int(date.timeIntervalSince(start)))
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }
}
