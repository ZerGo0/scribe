import Foundation

struct TextReplacement: Codable, Equatable, Identifiable, Sendable {
  var id = UUID()
  var heard: String
  var replacement: String

  static func apply(_ rules: [TextReplacement], to text: String) -> String {
    rules.reduce(text) { result, rule in
      guard let pattern = rule.pattern else { return result }
      return pattern.stringByReplacingMatches(
        in: result,
        range: NSRange(result.startIndex..., in: result),
        withTemplate: NSRegularExpression.escapedTemplate(for: rule.replacement)
      )
    }
  }

  private var pattern: NSRegularExpression? {
    let words = heard.split(whereSeparator: \.isWhitespace).map {
      NSRegularExpression.escapedPattern(for: String($0))
    }
    guard !words.isEmpty else { return nil }
    return try? NSRegularExpression(
      pattern: "(?<![\\p{L}\\p{N}])\(words.joined(separator: "\\s+"))(?![\\p{L}\\p{N}])",
      options: [.caseInsensitive]
    )
  }
}
