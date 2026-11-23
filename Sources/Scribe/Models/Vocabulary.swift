import Foundation

enum Vocabulary {
  static func terms(from text: String) -> [String] {
    var seen = Set<String>()
    return text
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
  }

  static func prompt(_ terms: [String]) -> String? {
    terms.isEmpty ? nil : terms.joined(separator: ", ")
  }
}
