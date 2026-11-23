import SwiftUI

struct CleanupSettingsPane: View {
  @ObservedObject var settings: AppSettings

  var body: some View {
    Form {
      Section {
        Toggle(isOn: $settings.audioProcessing.removeLowHum) {
          Text("Remove low hum")
          Text("Filters out rumble below 80 Hz.")
        }
        Toggle(isOn: $settings.audioProcessing.normalizeLevel) {
          Text("Normalize volume")
          Text("Makes quiet recordings louder.")
        }
        Toggle(isOn: $settings.audioProcessing.trimSilence) {
          Text("Trim silence")
          Text("Removes long pauses and splits long recordings at pauses.")
        }
      } header: {
        Text("Recording")
      } footer: {
        Text("Scribe cleans each recording before it transcribes it.")
      }

      Section {
        Toggle(isOn: $settings.textCleanup.removeFillers) {
          Text("Remove filler words")
          Text("Removes “um”, “uh”, “äh”, and similar sounds in the language you speak.")
        }
        Toggle(isOn: $settings.textCleanup.removeRepeatedWords) {
          Text("Remove repeated words")
          Text("Turns “I I think” into “I think”.")
        }
        Toggle(isOn: $settings.textCleanup.applySpokenLineBreaks) {
          Text("Spoken line breaks")
          Text("Say “new line” or “new paragraph” to start a new line.")
        }
      } header: {
        Text("Text")
      } footer: {
        Text("Scribe cleans the text before it pastes it.")
      }
    }
    .formStyle(.grouped)
  }
}
