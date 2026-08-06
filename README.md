# Scribe

Scribe is a simple speech-to-text app for macOS.

Press a shortcut to start talking. Press it again to stop. Your text is then pasted into the app you are using.

## What it does

- Runs from the menu bar
- Lets you choose your own shortcut
- Transcribes entirely on-device with Apple's Speech framework
- Includes Apple's heavy-accent recognition hint and custom vocabulary
- Works with OpenAI-compatible providers
- Uploads bandwidth-efficient 64 kbps MP3 audio
- Pastes completed dictations automatically
- Keeps your history for seven days
- Can start when you log in

## What you need

- macOS 14 or newer
- Xcode
- [Task](https://taskfile.dev)

## Run the app

Install it for everyday use:

```sh
task install
```

Open it:

```sh
open ~/Applications/Scribe.app
```

Scribe appears in your menu bar. It does not appear in the Dock.

## First-time setup

1. Open Scribe from the menu bar.
2. Open **Settings**.
3. Choose **Apple On-Device** or **OpenAI-compatible** for transcription.
4. For Apple, choose a speech mode and language. For a remote provider, enter its URL, API key,
   and model.
5. Allow Microphone and Accessibility access.
6. Choose your dictation shortcut.

If you want Scribe to open automatically, turn on **Launch at login**.

## Use it

1. Press your shortcut to start recording.
2. Speak.
3. Press the shortcut again to stop.
4. Wait for the text to appear.

You can view, search, copy, and delete past dictations from **History**.

## Your data

- Your API key is saved securely in the macOS Keychain.
- Apple On-Device recordings are processed locally and are never uploaded by Scribe.
- OpenAI-compatible recordings are uploaded to the provider you configure.
- Recordings are deleted after they are processed in either mode.
- Dictation history is deleted automatically after seven days.

## Apple speech modes

- **Heavy accent** uses Apple's `DictationTranscriber` with the public `atypicalSpeech` hint.
- **Dictation** uses the same on-device model family as macOS system Dictation.
- **General conversation** uses Apple's newer `SpeechTranscriber` when the device supports it and
  falls back to Dictation otherwise.
- **Legacy recognizer** uses on-device `SFSpeechRecognizer` for comparison and compatibility.

The modern Apple modes require macOS 26 or newer. On macOS 14 and 15, Scribe automatically uses
the legacy on-device recognizer. Language assets download through macOS when first needed. Scribe
uses only Apple's public Speech APIs; Apple does not currently provide a public selector for the
private AFM 3 dictation transcriber.

Scribe uses the dynamically linked
[LAME MP3 encoder](https://github.com/BB9z/LAME-xcframework). Its license files are included in
the application bundle.

## Run the tests

```sh
task test
```
