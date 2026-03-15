import Foundation

struct TitleDetectionEngine {
    func detectTitleCandidate(in segment: StructuralSegment) -> (title: String?, confidence: ParsingConfidence, inferred: Bool) {
        let text = segment.normalizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return (nil, .low, false) }
        
        let lines = text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? text
        let wordCount = firstLine.split(separator: " ").count
        let isShortLine = wordCount > 0 && wordCount <= 8
        let endsWithColon = firstLine.hasSuffix(":")
        let isMostlyUppercase = firstLine == firstLine.uppercased() && firstLine.rangeOfCharacter(from: .letters) != nil
        let isTitleCase = firstLine.split(separator: " ").allSatisfy { token in
            guard let first = token.first else { return false }
            return first.isUppercase || token.count <= 3
        }
        let followedByLongerBody = lines.count >= 2 && (lines.dropFirst().joined(separator: " ").count > firstLine.count + 20)
        
        if endsWithColon {
            return (stripTrailingColon(firstLine), .high, false)
        }
        if isShortLine && followedByLongerBody && (isTitleCase || segment.looksLikeHeading || isMostlyUppercase) {
            return (firstLine, .high, false)
        }
        if isShortLine && (isTitleCase || isMostlyUppercase) {
            return (firstLine, .medium, false)
        }
        if segment.isVeryShort && !text.contains("\n") {
            return (firstLine, .low, true)
        }
        return (nil, .low, false)
    }
    
    func fallbackTitle(from text: String) -> String {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        let tokens = cleaned
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .prefix(5)
            .map { token in
                token.prefix(1).uppercased() + token.dropFirst().lowercased()
            }
            .joined(separator: " ")
        return tokens.isEmpty ? "Recovered Fragment" : tokens
    }
    
    private func stripTrailingColon(_ value: String) -> String {
        value.hasSuffix(":") ? String(value.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines) : value
    }
}
