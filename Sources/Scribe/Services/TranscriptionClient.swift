import Foundation

struct TranscriptionRequest: Sendable {
  let provider: TranscriptionProvider
  let remoteConfiguration: ProviderConfiguration
  let appleConfiguration: AppleSpeechConfiguration
  let apiKey: String
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

  func transcribe(audioURL: URL, request: TranscriptionRequest) async throws -> String {
    switch request.provider {
    case .openAICompatible:
      try await remote.transcribe(
        audioURL: audioURL,
        provider: request.remoteConfiguration,
        apiKey: request.apiKey
      )
    case .appleOnDevice:
      try await apple.transcribe(audioURL: audioURL, configuration: request.appleConfiguration)
    }
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
    apiKey: String
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

  private static func multipartBody(boundary: String, model: String, audioURL: URL) throws -> Data {
    var body = Data()
    body.appendUTF8("--\(boundary)\r\n")
    body.appendUTF8("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
    body.appendUTF8("\(model)\r\n")
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
