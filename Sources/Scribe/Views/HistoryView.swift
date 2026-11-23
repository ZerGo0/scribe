import AppKit
import SwiftUI

struct HistoryView: View {
  @ObservedObject var history: HistoryStore
  @State private var searchText = ""
  @State private var isConfirmingClear = false
  @State private var copiedID: UUID?

  private let copiedFeedbackDuration = Duration.seconds(1.5)

  var body: some View {
    content
      .frame(minWidth: 540, minHeight: 380)
      .searchable(text: $searchText, placement: .toolbar, prompt: "Search")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button(role: .destructive) {
            isConfirmingClear = true
          } label: {
            Label("Clear History", systemImage: "trash")
          }
          .help("Delete all dictations")
          .disabled(history.transcripts.isEmpty)
        }
      }
      .confirmationDialog("Delete all dictations?", isPresented: $isConfirmingClear) {
        Button("Delete All", role: .destructive) { history.clear() }
      } message: {
        Text("You cannot undo this.")
      }
      .onAppear { history.pruneExpired() }
  }

  @ViewBuilder
  private var content: some View {
    if history.transcripts.isEmpty {
      ContentUnavailableView(
        "No Dictations Yet",
        systemImage: "waveform",
        description: Text("Your dictations appear here. Scribe keeps them for seven days.")
      )
    } else if filteredTranscripts.isEmpty {
      ContentUnavailableView.search(text: searchText)
    } else {
      List {
        ForEach(daySections, id: \.day) { section in
          Section(sectionTitle(section.day)) {
            ForEach(section.transcripts) { transcript in
              row(transcript)
            }
            .onDelete { offsets in
              history.delete(ids: Set(offsets.map { section.transcripts[$0].id }))
            }
          }
        }
      }
    }
  }

  private func row(_ transcript: Transcript) -> some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 6) {
        Text(transcript.text)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
        HStack(spacing: 12) {
          Label(transcript.createdAt.formatted(date: .omitted, time: .shortened), systemImage: "clock")
          Label(duration(transcript.duration), systemImage: "mic")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }

      Button {
        copy(transcript)
      } label: {
        Label(
          copiedID == transcript.id ? "Copied" : "Copy",
          systemImage: copiedID == transcript.id ? "checkmark" : "doc.on.doc"
        )
      }
      .controlSize(.small)
    }
    .padding(.vertical, 4)
    .contextMenu {
      Button("Copy") { copy(transcript) }
      Button("Delete", role: .destructive) { history.delete(id: transcript.id) }
    }
  }

  private var filteredTranscripts: [Transcript] {
    history.transcripts(matching: searchText)
  }

  private var daySections: [(day: Date, transcripts: [Transcript])] {
    let calendar = Calendar.current
    let grouped = Dictionary(grouping: filteredTranscripts) { calendar.startOfDay(for: $0.createdAt) }
    return grouped.keys.sorted(by: >).map { (day: $0, transcripts: grouped[$0] ?? []) }
  }

  private func sectionTitle(_ day: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(day) { return "Today" }
    if calendar.isDateInYesterday(day) { return "Yesterday" }
    return day.formatted(.dateTime.weekday(.wide).month(.wide).day())
  }

  private func duration(_ seconds: TimeInterval) -> String {
    let value = max(0, Int(seconds.rounded()))
    return String(format: "%d:%02d", value / 60, value % 60)
  }

  private func copy(_ transcript: Transcript) {
    ClipboardInserter.copy(transcript.text)
    copiedID = transcript.id
    Task {
      try? await Task.sleep(for: copiedFeedbackDuration)
      if copiedID == transcript.id { copiedID = nil }
    }
  }
}
