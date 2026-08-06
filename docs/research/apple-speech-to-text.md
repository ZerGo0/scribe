# Apple speech-to-text options for accented speech

Research date: 2026-08-06

## Bottom line

Apple's local speech recognition is worth testing for Scribe, but Apple does not publish enough accent-specific evidence to predict whether it will understand one particular speaker.

The strongest candidates are:

1. **macOS 27 system Dictation with AFM 3 Core Advanced** is the most promising quality signal. Apple reports a substantial overall preference win over its previous production Dictation system, but this is currently a system feature in developer-testing software, not a documented speech API that Scribe can call directly.
2. **`SpeechAnalyzer` with `SpeechTranscriber`** is Apple's best modern, embeddable, entirely on-device transcription path on macOS 26 and later. Apple calls it faster and more flexible than `SFSpeechRecognizer`, but provides no accent-specific benchmark or accent-adaptation control.
3. **`DictationTranscriber` with `.atypicalSpeech`** is the only Apple API explicitly documented for a speaker with a heavy accent. It uses the same on-device models as system Dictation and on-device `SFSpeechRecognizer`, rather than the newer `SpeechTranscriber` model.

The practical next step is a small, same-audio bake-off using the speaker's real clips and the closest plausible regional locales. Do not choose from Apple's marketing claims alone.

## Follow-up: can a third-party app invoke AFM 3 dictation directly?

Follow-up checked: 2026-08-06

**No supported or publicly reproduced path was found.** There is good evidence that the implementation exists on the system, including a hidden `Speech.FoundationModelTranscriber` type, but no public API, command, repository, or reproducible sample was found that lets a third-party process feed audio to AFM 3 Core Advanced and receive its transcript. Confidence is **high for the current macOS/Xcode 27 beta surface**, but this can change during the beta.

Keep these similarly named paths separate:

- **Foundation Models API, Python SDK, and `fm`: AFM 3 access, but not AFM 3 speech input.** Apple says qualifying hardware can run Core Advanced, so `SystemLanguageModel` may use that model for the tasks Apple exposes. The public surface is text and image prompting: the Xcode 27 SDK's only attachment content is `ImageAttachmentContent`, and its only declared media capability is `vision`. Apple's `fm` session likewise documents text and image input. The locally shipped `fm` command exposes `--text` and `--image`, while `fm serve` exposes only chat completions, not `/audio/transcriptions`. [Foundation Models documentation](https://developer.apple.com/documentation/foundationmodels/), [Apple's WWDC26 `fm` and Python session](https://developer.apple.com/videos/play/wwdc2026/334/), [Apple staff on Core versus Core Advanced hardware routing](https://developer.apple.com/forums/thread/832910)
- **`SpeechTranscriber` and `DictationTranscriber`: public audio APIs, but not documented AFM 3 selectors.** Neither public class has an AFM model choice, an AFM asset identifier, or a Core Advanced capability flag in the Xcode 27 public interface. `DictationTranscriber`'s documentation says it uses the same speech-to-text model family as system Dictation, but it does not identify the new AFM model or promise that the public module selects it on eligible macOS 27 hardware. In a WWDC26 Foundation Models Q&A, Apple's answer to a speech-recognition question was simply to use the Speech framework; it did not identify an AFM 3 entry point. [`SpeechTranscriber`](https://developer.apple.com/documentation/speech/speechtranscriber), [`DictationTranscriber`](https://developer.apple.com/documentation/speech/dictationtranscriber), [Apple Frameworks Engineer answer](https://developer.apple.com/forums/thread/833661)
- **System Dictation: confirmed AFM 3 feature, but user-facing.** Apple documents higher-accuracy systemwide Dictation on qualifying Macs and describes AFM 3 Core Advanced's speech-to-text evaluation. This path is invoked through the system Dictation UI and inserts text into the focused control; Apple does not document an API for supplying an audio file or receiving a transcript programmatically. [Apple Newsroom](https://www.apple.com/newsroom/2026/06/apple-introduces-siri-ai-a-profoundly-more-capable-and-personal-assistant/), [AFM 3 research](https://machinelearning.apple.com/research/introducing-third-generation-of-apple-foundation-models)
- **Private implementation: discovered, not product-usable.** In the installed Xcode 27 beta 2 SDK, `Speech.tbd` exports Swift ABI symbols for a hidden `Speech.FoundationModelTranscriber`. Its apparent shape includes locale/preset initializers, compatible audio formats, async results, and `SpeechModule` conformance. `CoreEmbeddedSpeechRecognition.tbd` also contains `useFoundationModelTranscriber`. However, the type is absent from `Speech.swiftinterface`; both normal and `@_spi` imports fail with “cannot find `FoundationModelTranscriber` in scope.” Reproducing the check only requires searching those two `.tbd` files under `$(xcrun --sdk macosx --show-sdk-path)`. Calling it would require reconstructing private Swift ABI and possibly private asset/sandbox requirements, and would violate the App Store rule that apps use public APIs. [App Review Guideline 2.5.1](https://developer.apple.com/app-store/review/guidelines/)
- **Community reverse engineering: plumbing found, invocation not found.** The most concrete public teardown found `com.apple.fm.language.instruct_3b.asr_afmdictation`, `asr_fullpayloadcorrection`, and `asr_natural_dictation_speech` catalog entries and mapped the sparse variant to Core Advanced. Its own CLI reference shows only text/image prompts and says the additional adapters are not selectable from `fm`. The repository contains catalog strings and model-loading observations, but no code that sends audio to those adapters. [`fm` teardown](https://github.com/llostinthesauce/fm-teardown), [model architecture findings](https://github.com/llostinthesauce/fm-teardown/blob/main/02_MODEL_ARCHITECTURE.md), [`fm` CLI reference](https://github.com/llostinthesauce/fm-teardown/blob/main/01_CLI_REFERENCE.md)

For Scribe, this means there is not yet a defensible AFM 3 backend to implement. A prototype should still compare the public speech APIs, but a good result from `SpeechTranscriber` or `DictationTranscriber` must not be labeled “AFM 3” unless runtime asset/log evidence proves that specific route. The only currently verifiable AFM 3 speech test is system Dictation itself.

## Options

### macOS 27 system Dictation: the newest built-in model

Apple's 2026 `AFM 3 Core Advanced` is a 20-billion-parameter, sparsely activated, natively multimodal model that runs on-device and is used for higher-accuracy systemwide Dictation. In Apple's side-by-side human evaluation, the new Dictation output was preferred for overall quality on 44.7% of samples versus 17.6% for the previous production system; it also won consistently on punctuation, casing, layout, meaning capture, disfluency handling, and style. Apple does not publish an accent subgroup or word-error-rate breakdown for this evaluation. The research page only clarifies that its broader English evaluation sets include dialects from the US, Great Britain, Australia, and India; it does not say that the Dictation evaluation was broken out the same way. [Apple Machine Learning Research](https://machinelearning.apple.com/research/introducing-third-generation-of-apple-foundation-models)

This advanced Dictation model requires a Mac with M3 or later and at least 12 GB of unified memory. As of the research date, Apple describes the macOS 27 features as available for developer testing, with a user beta later in 2026. [Apple Newsroom](https://www.apple.com/newsroom/2026/06/apple-introduces-siri-ai-a-profoundly-more-capable-and-personal-assistant/)

This is a promising **system Dictation test**, not yet a safe Scribe dependency. Apple's public Foundation Models API documents text and image inputs, not raw audio input, and Apple has not documented a way for third-party apps to invoke the AFM 3 Dictation specialization. That conclusion is an inference from the currently published APIs. [Foundation Models framework](https://developer.apple.com/documentation/foundationmodels/), [prompt attachments](https://developer.apple.com/documentation/foundationmodels/attachment)

### `SpeechAnalyzer` and `SpeechTranscriber`: modern embeddable STT

Introduced across Apple platforms in OS 26, `SpeechAnalyzer` and `SpeechTranscriber` use a newer, entirely on-device model than `SFSpeechRecognizer`. Apple says it is faster and more flexible, supports live, conversational, long-form, and distant audio, and powers features in Notes, Voice Memos, and Journal. Locale-specific model assets are downloaded through `AssetInventory`, live in system storage rather than the app bundle or process, update automatically, and can be queried at runtime. [Apple's WWDC25 SpeechAnalyzer session](https://developer.apple.com/videos/play/wwdc2025/277/), [`SpeechTranscriber` documentation](https://developer.apple.com/documentation/speech/speechtranscriber)

Apple's accuracy claims here are qualitative. It publishes no accent-specific word error rates, speaker adaptation, accent enrollment, or accent selector for `SpeechTranscriber`. Its configuration selects a `Locale` plus transcription, result-delivery, and result-attribute options. Apps must query `supportedLocales` and `installedLocales` on the actual device. [`SpeechTranscriber` initializer](https://developer.apple.com/documentation/speech/speechtranscriber/init%28locale%3Atranscriptionoptions%3Areportingoptions%3Aattributeoptions%3A%29)

The locale should describe the language and regional writing convention the speaker is producing, not simply the speaker's nationality. Apple warns that choosing a near-equivalent locale can produce differences such as “color” versus “colour,” and recommends exposing a way for the user to correct the locale. [`supportedLocale(equivalentTo:)`](https://developer.apple.com/documentation/speech/dictationtranscriber/supportedlocale%28equivalentto%3A%29)

### `DictationTranscriber`: older model, direct heavy-accent hint

`DictationTranscriber` uses the same speech-to-text models as system Dictation and on-device `SFSpeechRecognizer`. It can bias up to 100 short words or phrases with `AnalysisContext.contextualStrings`, use a custom language model for vocabulary and pronunciation, and alter processing with content hints. Apple's `.atypicalSpeech` hint explicitly means audio from a speaker with “a heavy accent, lisp, or other confounding factor.” This makes it the most directly relevant Apple API to test for the reported problem. [`DictationTranscriber` documentation](https://developer.apple.com/documentation/speech/dictationtranscriber), [`.atypicalSpeech`](https://developer.apple.com/documentation/speech/dictationtranscriber/contenthint/atypicalspeech), [`contextualStrings`](https://developer.apple.com/documentation/speech/analysiscontext/contextualstrings)

This is not the new `SpeechTranscriber` model. It is a configurable wrapper around the older on-device Dictation recognizer family, so it should be compared empirically rather than assumed to be better. Custom vocabulary can fix recurring proper nouns and domain terms, but it is not personal acoustic-model training. Apple's explanation of custom language models shows that they change which word sequences the recognizer expects and allow specific pronunciations; customized requests remain on-device. [Customize on-device speech recognition, WWDC23](https://developer.apple.com/videos/play/wwdc2023/10101/)

### Default macOS Dictation and legacy `SFSpeechRecognizer`

Default macOS Dictation is the quickest no-code proxy for the `DictationTranscriber` model family. macOS lets the user choose a language and region, install multiple choices, switch among them, and select the microphone. Current on-device English choices include Australia, Canada, India, Indonesia, Ireland, Japan, Malaysia, New Zealand, Philippines, Saudi Arabia, Singapore, South Africa, United Arab Emirates, United Kingdom, and United States. [Mac Dictation guide](https://support.apple.com/guide/mac-help/use-dictation-mh40584/mac), [macOS feature availability](https://www.apple.com/uk/macos/feature-availability/)

Whether ordinary Dictation is processed locally depends on the Mac and selected language. Apple tells users to check the message under **System Settings > Keyboard > Dictation** to confirm whether audio and transcripts stay on-device. [Mac Dictation guide](https://support.apple.com/guide/mac-help/use-dictation-mh40584/mac)

`SFSpeechRecognizer` remains the compatibility option for Scribe's older deployment targets. On-device support varies by device and locale. An app can require local recognition, but Apple warns that forced on-device requests are less accurate than the network path. It supports locale selection, contextual phrases, and custom language models, but has no documented heavy-accent hint. [`supportsOnDeviceRecognition`](https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition), [`requiresOnDeviceRecognition`](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition), [`SFSpeechRecognitionRequest`](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest)

## Relevance to Scribe

Scribe currently targets macOS 14 and uploads a completed MP3 recording to an OpenAI-compatible `/audio/transcriptions` endpoint. It has no local Speech framework path or locale setting. See [`Package.swift`](../../Package.swift) and [`TranscriptionClient.swift`](../../Sources/Scribe/Services/TranscriptionClient.swift).

Consequences:

- `SpeechAnalyzer`, `SpeechTranscriber`, and `DictationTranscriber` require an availability-gated macOS 26 path if Scribe keeps macOS 14 support.
- A local fallback on macOS 14 would use `SFSpeechRecognizer`; the accent-specific `.atypicalSpeech` hint is only available through the newer `DictationTranscriber` API.
- A local mode needs a locale selector or at least an explicit automatic choice that the user can override.
- The existing recorded audio can be reused for a fair model comparison, but the final implementation should feed a speech-compatible PCM format rather than assume the uploaded MP3 is the preferred analyzer input.
- The Foundation Models framework may be useful after transcription for cleanup or transformation, but its public API is not a replacement STT entry point.

This development machine (M4, 16 GB, macOS 27 beta) qualifies for AFM 3 Core Advanced. A runtime query also reports `SpeechTranscriber.isAvailable == true`; its current supported set includes `de_DE` and nine regional English locales (`en_AU`, `en_CA`, `en_GB`, `en_IE`, `en_IN`, `en_NZ`, `en_SG`, `en_US`, and `en_ZA`), and those English models are installed. This confirms that both system Dictation and an embeddable on-device prototype can be tested on the machine, not that either will handle the speaker's accent well.

## Suggested evaluation

Use 20–50 saved utterances that actually fail today, preserve one human-correct reference transcript per clip, and run the exact same audio through:

1. the current best remote model;
2. macOS 27 system Dictation, if the advanced model is active on the test Mac;
3. `SpeechTranscriber` with the closest regional locale, plus one or two plausible alternatives;
4. `DictationTranscriber` with the same locale, once normally and once with `.atypicalSpeech`;
5. optionally, legacy on-device `SFSpeechRecognizer` to establish the older-model baseline.

Compare word error rate, meaning-changing errors, proper-noun errors, and latency. Keep the locale and exact OS/model asset versions with each result because Apple updates the on-device assets automatically. This evaluation is the only reliable answer for one person's accent because Apple supplies no matching public benchmark.
