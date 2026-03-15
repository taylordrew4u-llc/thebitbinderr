import Foundation

struct TextNormalizationService {
    func normalize(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        
        var value = text
        value = value.replacingOccurrences(of: "\r\n", with: "\n")
        value = value.replacingOccurrences(of: "\r", with: "\n")
        value = replaceSmartPunctuation(in: value)
        value = value.replacingOccurrences(of: "\t", with: "    ")
        value = value.replacingOccurrences(of: "[ \u{00A0}]{2,}", with: " ", options: .regularExpression)
        value = value.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        value = value.replacingOccurrences(of: #"(?<=[A-Za-z0-9,])\n(?=[a-z])"#, with: " ", options: .regularExpression)
        value = value.replacingOccurrences(of: #"(?<=[a-z])\n(?=[a-z]{2,}\b)"#, with: " ", options: .regularExpression)
        value = value.replacingOccurrences(of: "[ ]+\n", with: "\n", options: .regularExpression)
        value = value.replacingOccurrences(of: #"^\s+|\s+$"#, with: "", options: [.regularExpression])
        return value
    }
    
    private func replaceSmartPunctuation(in text: String) -> String {
        text
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
            .replacingOccurrences(of: "‘", with: "'")
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
    }
}
