import AppKit
import SwiftUI

struct HistoryView: View {
  @ObservedObject var history: HistoryStore
  @State private var searchText = ""

  var body: some View {
    VStack(spacing: 0) {
      if history.transcripts.isEmpty {
        ContentUnavailableView(
          "No Dictations Yet",
          systemImage: "waveform",
          description: Text("Completed transcripts remain here for seven days.")
        )
      } else if filteredTranscripts.isEmpty {
        ContentUnavailableView.search(text: searchText)
      } else {
        List {
          ForEach(filteredTranscripts) { transcript in
            HStack(alignment: .top, spacing: 12) {
              VStack(alignment: .leading, spacing: 6) {
                Text(transcript.text)
                  .textSelection(.enabled)
                HStack {
                  Text(transcript.createdAt, format: .dateTime.month().day().hour().minute())
                  Text("·")
                  Text(duration(transcript.duration))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
              }
              .frame(maxWidth: .infinity, alignment: .leading)

              HStack(spacing: 6) {
                Button {
                  copy(transcript.text)
                } label: {
                  Image(systemName: "doc.on.doc")
                }
                .help("Copy transcript")
                .accessibilityLabel("Copy transcript")

                Button {
                  history.delete(id: transcript.id)
                } label: {
                  Image(systemName: "trash")
                }
                .foregroundStyle(.secondary)
                .help("Delete transcript")
                .accessibilityLabel("Delete transcript")
              }
              .buttonStyle(.borderless)
              .controlSize(.small)
            }
            .padding(.vertical, 5)
            .contextMenu {
              Button("Copy") { copy(transcript.text) }
              Button("Delete", role: .destructive) { history.delete(id: transcript.id) }
            }
          }
          .onDelete(perform: deleteFilteredTranscripts)
        }
      }

      Divider()
      HStack {
        Text("Items are deleted automatically after seven days.")
          .font(.callout)
          .foregroundStyle(.secondary)
        Spacer()
        Button("Clear History", role: .destructive) { history.clear() }
          .disabled(history.transcripts.isEmpty)
      }
      .padding(12)
    }
    .frame(minWidth: 520, minHeight: 360)
    .searchable(text: $searchText, placement: .toolbar, prompt: "Search history")
    .onAppear { history.pruneExpired() }
  }

  private var filteredTranscripts: [Transcript] {
    history.transcripts(matching: searchText)
  }

  private func duration(_ seconds: TimeInterval) -> String {
    let value = max(0, Int(seconds.rounded()))
    return String(format: "%d:%02d", value / 60, value % 60)
  }

  private func copy(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
  }

  private func deleteFilteredTranscripts(at offsets: IndexSet) {
    let ids = Set(
      offsets.compactMap { index in
        filteredTranscripts.indices.contains(index) ? filteredTranscripts[index].id : nil
      })
    history.delete(ids: ids)
  }
}
