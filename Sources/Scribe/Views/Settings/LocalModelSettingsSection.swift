import SwiftUI

struct LocalModelSettingsSection: View {
  @ObservedObject var settings: AppSettings
  @ObservedObject var library: LocalModelLibrary

  var body: some View {
    Section {
      ForEach(LocalSpeechModel.allCases, id: \.self) { model in
        modelRow(model)
      }
    } header: {
      Text("Model")
    } footer: {
      if let errorMessage = library.errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.circle")
          .foregroundStyle(.red)
      } else {
        Text("Scribe loads the model only while it transcribes, then frees the memory.")
      }
    }

    if settings.localModel.fixedLanguageCode == nil {
      Section {
        Picker("Language", selection: languageSelection) {
          Text("Automatic").tag(String?.none)
          Divider()
          ForEach(languageOptions, id: \.code) { option in
            Text(option.name).tag(Optional(option.code))
          }
        }
      } footer: {
        Text(
          "Scribe uses the language to remove the right filler words. \(settings.localModel.displayName) can still switch between languages that use the same alphabet, such as English and German. To get only English, choose Parakeet English."
        )
      }
    }
  }

  private func modelRow(_ model: LocalSpeechModel) -> some View {
    let isSelected = settings.localModel == model
    return HStack(spacing: 12) {
      Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
        .font(.title3)
        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(model.displayName)
        Text(model.detail)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 12)
      status(for: model)
    }
    .padding(.vertical, 2)
    .contentShape(Rectangle())
    .onTapGesture { settings.localModel = model }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    .accessibilityAction { settings.localModel = model }
  }

  @ViewBuilder
  private func status(for model: LocalSpeechModel) -> some View {
    if let progress = library.downloadProgress[model] {
      HStack(spacing: 8) {
        ProgressView(value: progress)
          .frame(width: 90)
        Text(progress.formatted(.percent.precision(.fractionLength(0))))
          .monospacedDigit()
          .foregroundStyle(.secondary)
          .frame(width: 40, alignment: .trailing)
      }
    } else if library.isDownloaded(model) {
      HStack(spacing: 8) {
        Text("Downloaded")
          .foregroundStyle(.secondary)
        Button(role: .destructive) {
          library.delete(model)
        } label: {
          Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
        .help("Delete \(model.displayName)")
        .accessibilityLabel("Delete \(model.displayName)")
      }
    } else {
      Button("Download \(downloadSize(model))") { library.download(model) }
    }
  }

  private func downloadSize(_ model: LocalSpeechModel) -> String {
    Measurement(value: Double(model.approximateDownloadMegabytes), unit: UnitInformationStorage.megabytes)
      .formatted(.byteCount(style: .file))
  }

  private var supportedLanguageCodes: Set<String> {
    library.supportedLanguageCodes(for: settings.localModel)
  }

  private var languageSelection: Binding<String?> {
    Binding(
      get: {
        settings.localModelLanguage.flatMap { supportedLanguageCodes.contains($0) ? $0 : nil }
      },
      set: { settings.localModelLanguage = $0 }
    )
  }

  private var languageOptions: [(code: String, name: String)] {
    supportedLanguageCodes
      .map { (code: $0, name: Locale.current.localizedString(forLanguageCode: $0) ?? $0) }
      .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }
}
