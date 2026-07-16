# Scribe

Scribe is a simple speech-to-text app for macOS.

Press a shortcut to start talking. Press it again to stop. Your text is then pasted into the app you are using.

## What it does

- Runs from the menu bar
- Lets you choose your own shortcut
- Works with OpenAI-compatible providers
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
3. Enter your provider URL and API key.
4. Choose a model or enter one manually.
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
- Recordings are deleted after they are processed.
- Dictation history is deleted automatically after seven days.

## Run the tests

```sh
task test
```
