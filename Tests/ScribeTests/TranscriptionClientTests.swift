import Foundation
import XCTest

@testable import Scribe

final class TranscriptionClientTests: XCTestCase, @unchecked Sendable {
  override func tearDown() {
    MockURLProtocol.handler = nil
    super.tearDown()
  }

  func testTranscriptionUsesCompatibleEndpointAuthorizationAndMultipartBody() async throws {
    let audio = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString + ".mp3")
    try Data("audio-data".utf8).write(to: audio)
    defer { try? FileManager.default.removeItem(at: audio) }

    MockURLProtocol.handler = { request in
      XCTAssertEqual(request.url?.absoluteString, "https://provider.test/v1/audio/transcriptions")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
      let body = try XCTUnwrap(bodyData(from: request))
      let bodyText = String(decoding: body, as: UTF8.self)
      XCTAssertTrue(bodyText.contains("name=\"model\"\r\n\r\nspeech-model"))
      XCTAssertTrue(bodyText.contains("name=\"file\"; filename=\"dictation.mp3\""))
      XCTAssertTrue(bodyText.contains("Content-Type: audio/mpeg"))
      XCTAssertTrue(bodyText.contains("audio-data"))
      return (
        HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
        Data(#"{"text":" Hello world "}"#.utf8)
      )
    }

    let client = OpenAITranscriptionClient(session: mockSession())
    let result = try await client.transcribe(
      audioURL: audio,
      provider: .init(baseURL: "https://provider.test/v1/", model: "speech-model"),
      apiKey: "secret"
    )
    XCTAssertEqual(result, "Hello world")
  }

  func testModelsAreSorted() async throws {
    MockURLProtocol.handler = { request in
      XCTAssertEqual(request.url?.absoluteString, "https://provider.test/v1/models")
      let data = Data(#"{"data":[{"id":"z-model"},{"id":"a-model"}]}"#.utf8)
      return (
        HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
        data
      )
    }
    let models = try await OpenAITranscriptionClient(session: mockSession()).models(
      provider: .init(baseURL: "https://provider.test/v1", model: ""),
      apiKey: "secret"
    )
    XCTAssertEqual(models, ["a-model", "z-model"])
  }

  func testProviderErrorMessageIsPreserved() async throws {
    let audio = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try Data().write(to: audio)
    defer { try? FileManager.default.removeItem(at: audio) }
    MockURLProtocol.handler = { request in
      let data = Data(#"{"error":{"message":"model unavailable"}}"#.utf8)
      return (
        HTTPURLResponse(url: request.url!, statusCode: 422, httpVersion: nil, headerFields: nil)!,
        data
      )
    }

    do {
      _ = try await OpenAITranscriptionClient(session: mockSession()).transcribe(
        audioURL: audio,
        provider: .init(baseURL: "https://provider.test/v1", model: "bad"),
        apiKey: "secret"
      )
      XCTFail("Expected an error")
    } catch {
      XCTAssertTrue(error.localizedDescription.contains("422: model unavailable"))
    }
  }

  private func mockSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: configuration)
  }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
  nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let handler = Self.handler else {
      XCTFail("Missing request handler")
      return
    }
    do {
      let (response, data) = try handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}

private func bodyData(from request: URLRequest) -> Data? {
  if let body = request.httpBody { return body }
  guard let stream = request.httpBodyStream else { return nil }
  stream.open()
  defer { stream.close() }
  var data = Data()
  var buffer = [UInt8](repeating: 0, count: 4_096)
  while stream.hasBytesAvailable {
    let count = stream.read(&buffer, maxLength: buffer.count)
    guard count > 0 else { break }
    data.append(buffer, count: count)
  }
  return data
}
