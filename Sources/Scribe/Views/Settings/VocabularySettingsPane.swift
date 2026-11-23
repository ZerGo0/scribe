import SwiftUI

struct VocabularySettingsPane: View {
  @ObservedObject var settings: AppSettings
  @State private var draft = ""

  private let editorMinimumHeight: CGFloat = 96

  var body: some View {
    Form {
      Section {
        TextEditor(text: $draft)
          .font(.body)
          .scrollContentBackground(.hidden)
          .frame(minHeight: editorMinimumHeight)
          .overlay(alignment: .topLeading) {
            if draft.isEmpty {
              Text("Scribe, Hugging Face, Kubernetes")
                .foregroundStyle(.tertiary)
                .padding(.leading, 5)
                .allowsHitTesting(false)
            }
          }
          .accessibilityLabel("Names and terms")
            .onChange(of: draft) { _, value in
            settings.vocabulary = Vocabulary.terms(from: value)
          }
      } header: {
        Text("Words to spell correctly")
      } footer: {
        Text(footer)
      }
    }
    .formStyle(.grouped)
    .onAppear { draft = Vocabulary.prompt(settings.vocabulary) ?? "" }
  }

  private var footer: String {
    let help =
      "Separate entries with commas. Scribe gives this list to every provider, so names and special words come out spelled the way you want."
    switch settings.vocabulary.count {
    case 0: return help
    case 1: return "\(help) 1 entry saved."
    case let count: return "\(help) \(count) entries saved."
    }
  }
}
