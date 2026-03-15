import Foundation
import NaturalLanguage

struct TagExtractionService {
    private let knownThemes = [
        "dating", "family", "work", "money", "therapy", "body", "sex", "apps", "new york city",
        "travel", "airport", "marriage", "parents", "kids", "gym", "doctor", "food", "phone"
    ]
    
    func extractTags(from text: String) -> [String] {
        let lower = text.lowercased()
        var tags = Set<String>()
        
        for theme in knownThemes where lower.contains(theme) {
            tags.insert(normalizeTag(theme))
        }
        
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = text
        let range = text.startIndex..<text.endIndex
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]
        
        tagger.enumerateTags(in: range, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            let token = String(text[tokenRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if let tag, !token.isEmpty, token.count > 2 {
                switch tag {
                case .personalName, .placeName, .organizationName:
                    tags.insert(normalizeTag(token))
                default:
                    break
                }
            }
            return true
        }
        
        tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange in
            let token = String(text[tokenRange]).lowercased()
            if tag == .noun || tag == .otherWord {
                if token.count >= 4, !commonStopwords.contains(token) {
                    tags.insert(normalizeTag(token))
                }
            }
            return true
        }
        
        return Array(tags).sorted().prefix(6).map { $0 }
    }
    
    private func normalizeTag(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }
    
    private let commonStopwords: Set<String> = [
        "that", "this", "with", "from", "they", "have", "about", "there", "their", "would",
        "could", "should", "really", "because", "after", "before", "thing", "things", "being"
    ]
}
