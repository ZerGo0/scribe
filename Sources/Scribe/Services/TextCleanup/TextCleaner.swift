import Foundation
import NaturalLanguage

enum TextCleaner {
  private static let fillerWords: [String: [String]] = [
    "de": ["äh", "ähm", "öh", "öhm", "ehm", "hm", "hmm"],
    "en": ["um", "umm", "uh", "uhh", "uhm", "er", "erm", "hmm"],
    "es": ["eh", "ehm", "em"],
    "fr": ["euh", "heu"],
    "it": ["ehm", "eh"],
    "nl": ["eh", "ehm", "uhm"],
  ]
  private static let meaningfulRepeats: [String: Set<String>] = [
    "de": ["der", "die", "das", "sie", "ja", "nein", "sehr", "so"],
    "en": ["had", "that", "bye", "very", "so", "no", "yes", "yeah", "really"],
  ]
  private static let lineBreakCommands = [
    ("new paragraph", "\n\n"),
    ("neuer absatz", "\n\n"),
    ("new line", "\n"),
    ("neue zeile", "\n"),
  ]
  private static let minimumDetectionConfidence = 0.6
  private static let capitalizeMarker = "\u{1}"
  private static let letter = "\\p{L}"

  static func cleaned(_ text: String, options: TextCleanupOptions, languageCode: String?) -> String {
    guard options.isEnabled else { return text }
    let language = languageCode ?? detectedLanguage(of: text)
    var result = text
    if options.applySpokenLineBreaks {
      result = applyingLineBreakCommands(to: result)
    }
    if options.removeFillers, let language, let fillers = fillerWords[language] {
      result = removingFillers(fillers, from: result)
    }
    if options.removeRepeatedWords {
      result = removingRepeatedWords(from: result, keeping: meaningfulRepeats[language ?? ""] ?? [])
    }
    return tidied(result)
  }

  static func detectedLanguage(of text: String) -> String? {
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(text)
    guard let (language, confidence) = recognizer.languageHypotheses(withMaximum: 1).first,
      confidence >= minimumDetectionConfidence
    else { return nil }
    return language.rawValue
  }

  private static func applyingLineBreakCommands(to text: String) -> String {
    lineBreakCommands.reduce(text) { result, command in
      let phrase = command.0.split(separator: " ").map { NSRegularExpression.escapedPattern(for: String($0)) }
        .joined(separator: "[ \\t]+")
      return replacing(
        "[ \\t]*(?<!\(letter))\(phrase)(?!\(letter))[ \\t]*[,.]?[ \\t]*",
        in: result
      ) { _ in command.1 }
    }
  }

  private static func removingFillers(_ fillers: [String], from text: String) -> String {
    let alternatives = fillers.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
    return replacing(
      "[ \\t]*,?[ \\t]*(?<!\(letter))(?:\(alternatives))(?!\(letter))(?:[ \\t]*,)?",
      in: text
    ) { match in
      let before = text[..<match.range.lowerBound].trimmingCharacters(in: .whitespaces)
      let startsSentence = before.isEmpty || before.last.map { ".!?\n".contains($0) } == true
      guard startsSentence else { return "" }
      return before.isEmpty ? capitalizeMarker : " " + capitalizeMarker
    }
  }

  private static func removingRepeatedWords(from text: String, keeping allowed: Set<String>) -> String {
    replacing("(?<!\(letter))(\(letter)+)(?:,?[ \\t]+\\1)+(?!\(letter))", in: text) { match in
      let word = String(text[match.groups[0]])
      return allowed.contains(word.lowercased()) ? String(text[match.range]) : word
    }
  }

  private static func tidied(_ text: String) -> String {
    var result = replacing("[ \\t]+\\n", in: text) { _ in "\n" }
    result = replacing("\\n[ \\t]+", in: result) { _ in "\n" }
    result = replacing("[ \\t]{2,}", in: result) { _ in " " }
    result = replacing("(^|\\n)[ \\t]*[,;][ \\t]*", in: result) { match in String(result[match.groups[0]]) }
    result = replacing("\(capitalizeMarker)[ \\t]*[,;]?[ \\t]*", in: result) { _ in capitalizeMarker }
    result = replacing("(?:(?<=\\n)|\(capitalizeMarker))(\\p{Ll})", in: result) { match in
      String(result[match.groups[0]]).uppercased()
    }
    return result.replacingOccurrences(of: capitalizeMarker, with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private struct Match {
    let range: Range<String.Index>
    let groups: [Range<String.Index>]
  }

  private static func replacing(
    _ pattern: String,
    in text: String,
    with replacement: (Match) -> String
  ) -> String {
    guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    else { return text }
    var result = text
    let matches = expression.matches(in: text, range: NSRange(text.startIndex..., in: text))
    for match in matches.reversed() {
      guard let range = Range(match.range, in: text) else { continue }
      let groups = (1..<max(match.numberOfRanges, 1)).compactMap { Range(match.range(at: $0), in: text) }
      let replacementText = replacement(Match(range: range, groups: groups))
      guard let target = Range(match.range, in: result) else { continue }
      result.replaceSubrange(target, with: replacementText)
    }
    return result
  }
}
