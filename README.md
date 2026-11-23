# Scribe

Scribe is a simple speech-to-text app for macOS.

Press a shortcut to start talking. Press it again to stop. Your text is then pasted into the app you are using.

## What it does

- Runs from the menu bar
- Lets you choose your own shortcut
- Transcribes entirely on-device with Apple's Speech framework
- Includes Apple's heavy-accent recognition hint
- Uses your list of names and terms with every provider, and replaces words that still come out
  wrong
- Keeps the microphone ready so the first word is not lost, and records a short moment after you
  stop
- Warns when the microphone is distorted, very quiet, or a low-quality Bluetooth microphone
- Transcribes on-device with a downloaded model: Parakeet Ultra for 25 languages, or Parakeet
  English for English only
- Cleans recordings before transcription: removes low hum, normalizes volume, and trims silence
- Cleans the text before pasting: removes filler words and repeated words, and turns "new line"
  into a line break
- Works with OpenAI-compatible providers
- Uploads bandwidth-efficient 64 kbps MP3 audio
- Pastes completed dictations automatically
- Keeps your history for seven days
- Can start when you log in

## What you need

- macOS 15 or newer on Apple silicon
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
3. Choose **Apple On-Device**, **Local Model**, or **OpenAI-compatible** for transcription.
4. For Apple, choose a speech mode and language. For a local model, choose a model and click **Download**. For a remote provider, enter its URL, API key, and model.
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
- Apple On-Device and Local Model recordings are processed locally and are never uploaded by
  Scribe. Scribe downloads local models from Hugging Face when you click **Download**.
- OpenAI-compatible recordings are uploaded to the provider you configure.
- Recordings are deleted after they are processed in either mode.
- Dictation history is deleted automatically after seven days.

## Apple speech modes

- **Heavy accent** uses Apple's `DictationTranscriber` with the public `atypicalSpeech` hint.
- **Dictation** uses the same on-device model family as macOS system Dictation.
- **General conversation** uses Apple's newer `SpeechTranscriber` when the device supports it and
  falls back to Dictation otherwise.
- **Legacy recognizer** uses on-device `SFSpeechRecognizer` for comparison and compatibility.

The modern Apple modes require macOS 26 or newer. On macOS 15, Scribe automatically uses
the legacy on-device recognizer. Language assets download through macOS when first needed. Scribe
uses only Apple's public Speech APIs; Apple does not currently provide a public selector for the
private AFM 3 dictation transcriber.

## Local models

| Model | Download | Runs on | Languages |
| --- | --- | --- | --- |
| Parakeet Ultra | About 730 MB | Neural Engine | English and 24 other European languages |
| Parakeet English | About 570 MB | Neural Engine | English only |

Parakeet Ultra can switch between languages that use the same alphabet, such as English and German,
even when you choose a language. If you dictate only in English, use Parakeet English: it never
switches to another language. For Parakeet Ultra, choose **Automatic** or a fixed language. Scribe
uses it to remove the right filler words and to keep the right alphabet.

Both downloads include a small helper model that applies your names and terms. Scribe runs it only
when your list of names and terms is not empty.

Models are saved in `~/Library/Application Support/Scribe/Models`. Scribe loads a model only while
it transcribes, then frees its memory. You can delete a model in **Settings**.

## Names and terms

Add names, product names, and special words in **Settings > Names and Terms**. Scribe sends them to
Apple Speech, the local models, and OpenAI-compatible providers to improve spelling.

Scribe also writes each entry with your exact spelling and capitals. If a word still comes out
wrong, add a replacement, for example "so paar Base" to "Supabase".
Scribe replaces whole words after every transcription and ignores case.

## Cleanup

Before transcription, Scribe can:

- Remove low hum with an 80 Hz high-pass filter
- Normalize the volume so that speech peaks at -3 dB
- Trim silence with Silero voice activity detection and split long recordings at pauses

Before pasting, Scribe can:

- Remove filler words such as "um", "uh", and "äh" in the language you speak
- Remove repeated words, such as "I I think"
- Turn "new line" and "new paragraph" (or "neue Zeile" and "neuer Absatz") into line breaks

Each step has its own setting in **Settings > Cleanup**, so you can compare results with and without
it.

## Third-party software

Scribe uses [FluidAudio](https://github.com/FluidInference/FluidAudio) and the dynamically linked
[LAME MP3 encoder](https://github.com/BB9z/LAME-xcframework). Their license files are included in
the application bundle.

## Run the tests

```sh
task test
```
