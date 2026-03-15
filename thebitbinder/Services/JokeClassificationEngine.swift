import Foundation

struct JokeClassificationEngine {
    func classify(_ segment: StructuralSegment) -> ImportedFragmentKind {
        let text = segment.normalizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()
        
        if segment.looksLikeHeading {
            return .title
        }
        if lower.hasPrefix("tag:") || lower.hasPrefix("tags:") {
            return .tag
        }
        if lower.hasPrefix("callback") || lower.contains("callback") {
            return .callbackReference
        }
        if lower.hasPrefix("note:") || lower.hasPrefix("notes:") {
            return .note
        }
        if text.count <= 28 {
            return .ideaFragment
        }
        if text.contains("?") && text.count <= 80 {
            return .premise
        }
        if lower.contains("because") || lower.contains("so that") || lower.contains("turns out") {
            return .setup
        }
        if lower.contains("then ") || lower.contains("and then") || lower.contains("that's when") {
            return .punchline
        }
        if segment.lineCount >= 2 || text.count > 45 {
            return .joke
        }
        return .unknown
    }
    
    func confidence(for segment: StructuralSegment, kind: ImportedFragmentKind) -> ParsingConfidence {
        switch kind {
        case .title:
            return segment.looksLikeHeading ? .high : .medium
        case .joke:
            return segment.lineCount >= 2 || segment.averageLineLength > 32 ? .high : .medium
        case .ideaFragment, .tag, .note, .callbackReference:
            return .medium
        case .unknown:
            return .low
        default:
            return .medium
        }
    }
}
