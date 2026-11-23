import Foundation

struct TranscriptionRequest: Sendable {
  let provider: TranscriptionProvider
  let remoteConfiguration: ProviderConfiguration
  let appleConfiguration: AppleSpeechConfiguration
  let localModel: LocalSpeechModel
  let localModelLanguage: String?
  let vocabulary: [String]
  let replacements: [TextReplacement]
  let audioProcessing: AudioProcessingOptions
  let textCleanup: TextCleanupOptions
  let apiKey: String

  var spokenLanguageCode: String? {
    switch provider {
    case .localModel: localModel.fixedLanguageCode ?? localModelLanguage
    case .appleOnDevice:
      Locale(identifier: appleConfiguration.normalizedLocaleIdentifier).language.languageCode?.identifier
    case .openAICompatible: nil
    }
  }
}

protocol Transcribing: Sendable {
  func transcribe(
    audioURL: URL,
    request: TranscriptionRequest
  ) async throws -> String
}

struct TranscriptionClient: Transcribing, Sendable {
  private let remote = OpenAITranscriptionClient()
  private let apple = AppleSpeechTranscriptionClient()
  private let local = LocalModelTranscriptionClient()

  func transcribe(audioURL: URL, request: TranscriptionRequest) async throws -> String {
    let text = try await rawTranscript(audioURL: audioURL, request: request)
    let spellings = request.vocabulary.map { TextReplacement(heard: $0, replacement: $0) }
    let cleaned = TextReplacement.apply(
      spellings + request.replacements,
      to: TextCleaner.cleaned(
        text,
        options: request.textCleanup,
        languageCode: request.spokenLanguageCode
      )
    )
    guard !cleaned.isEmpty else { throw DictationError.noSpeechDetected }
    return cleaned
  }

  private func rawTranscript(audioURL: URL, request: TranscriptionRequest) async throws -> String {
    if request.provider == .localModel {
      let chunks = try await AudioPreprocessor.speechChunks(
        from: audioURL,
        options: request.audioProcessing
      )
      guard !chunks.isEmpty else { throw DictationError.noSpeechDetected }
      return try await local.transcribe(
        chunks: chunks,
        model: request.localModel,
        language: request.localModelLanguage,
        vocabulary: request.vocabulary
      )
    }

    let processedURL = try await AudioPreprocessor.processedFile(
      from: audioURL,
      options: request.audioProcessing
    )
    defer {
      if processedURL != audioURL { try? FileManager.default.removeItem(at: processedURL) }
    }

    if request.provider == .appleOnDevice {
      return try await apple.transcribe(
        audioURL: processedURL,
        configuration: request.appleConfiguration,
        vocabulary: request.vocabulary
      )
    }

    let mp3URL = try MP3Encoder.encode(processedURL)
    defer { try? FileManager.default.removeItem(at: mp3URL) }
    return try await remote.transcribe(
      audioURL: mp3URL,
      provider: request.remoteConfiguration,
      apiKey: request.apiKey,
      prompt: Vocabulary.prompt(request.vocabulary)
    )
  }
}

struct OpenAITranscriptionClient: @unchecked Sendable {
  private let session: URLSession

  init(session: URLSession = .shared) {
    self.session = session
  }

  func transcribe(
    audioURL: URL,
    provider: ProviderConfiguration,
    apiKey: String,
    prompt: String? = nil
  ) async throws -> String {
    guard let baseURL = provider.normalizedBaseURL else {
      throw DictationError.invalidProviderURL
    }
    guard !apiKey.isEmpty else { throw DictationError.missingAPIKey }

    let boundary = "Scribe-\(UUID().uuidString)"
    let endpoint = baseURL.appendingPathComponent("audio/transcriptions")
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue(
      "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    request.httpBody = try Self.multipartBody(
      boundary: boundary,
      model: provider.model,
      prompt: prompt,
      audioURL: audioURL
    )

    let (data, response) = try await session.data(for: request)
    try Self.validate(response: response, data: data)
    let payload = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
    let text = payload.text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { throw DictationError.emptyTranscript }
    return text
  }

  func models(provider: ProviderConfiguration, apiKey: String) async throws -> [String] {
    guard let baseURL = provider.normalizedBaseURL else {
      throw DictationError.invalidProviderURL
    }
    guard !apiKey.isEmpty else { throw DictationError.missingAPIKey }

    var request = URLRequest(url: baseURL.appendingPathComponent("models"))
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await session.data(for: request)
    try Self.validate(response: response, data: data)
    let payload = try JSONDecoder().decode(ModelsResponse.self, from: data)
    return payload.data.map(\.id).sorted()
  }

  private static func multipartBody(
    boundary: String,
    model: String,
    prompt: String?,
    audioURL: URL
  ) throws -> Data {
    var body = Data()
    body.appendUTF8("--\(boundary)\r\n")
    body.appendUTF8("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
    body.appendUTF8("\(model)\r\n")
    if let prompt {
      body.appendUTF8("--\(boundary)\r\n")
      body.appendUTF8("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n")
      body.appendUTF8("\(prompt)\r\n")
    }
    body.appendUTF8("--\(boundary)\r\n")
    body.appendUTF8(
      "Content-Disposition: form-data; name=\"file\"; filename=\"dictation.mp3\"\r\n"
    )
    body.appendUTF8("Content-Type: audio/mpeg\r\n\r\n")
    body.append(try Data(contentsOf: audioURL))
    body.appendUTF8("\r\n--\(boundary)--\r\n")
    return body
  }

  private static func validate(response: URLResponse, data: Data) throws {
    guard let response = response as? HTTPURLResponse else {
      throw DictationError.requestFailed("The provider returned an invalid response.")
    }
    guard (200..<300).contains(response.statusCode) else {
      let payload = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
      let message =
        payload?.error.message
        ?? HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
      throw DictationError.requestFailed("\(response.statusCode): \(message)")
    }
  }
}

private struct TranscriptionResponse: Decodable {
  let text: String
}

private struct ModelsResponse: Decodable {
  struct Model: Decodable { let id: String }
  let data: [Model]
}

private struct APIErrorResponse: Decodable {
  struct APIError: Decodable { let message: String }
  let error: APIError
}

extension Data {
  fileprivate mutating func appendUTF8(_ string: String) {
    append(Data(string.utf8))
  }
}
