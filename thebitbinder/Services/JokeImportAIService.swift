import Foundation

/// Defines the expected output from the AI joke parsing logic.
struct ParsedJoke: Codable, Identifiable {
    let id = UUID()
    let title: String
    let premise: String?
    let punchline: String?
    let tags: [String]?
    let notes: String?
    let sourcePage: Int?
    let confidenceScore: Double?
    let rawTextSpan: String?
    
    enum CodingKeys: String, CodingKey {
        case title, premise, punchline, tags, notes, sourcePage, confidenceScore, rawTextSpan
    }
}

protocol JokeImportAIService {
    /// Extracts individual jokes from raw text.
    /// - Parameters:
    ///   - text: The full text extracted from a PDF or document
    ///   - pages: The page-level text info for preserving source page if possible
    /// - Returns: An array of structured joke data.
    func extractJokes(from text: String, pages: [PDFPageExtraction]?) async throws -> [ParsedJoke]
}

enum JokeImportAIErrors: Error {
    case serviceUnavailable
    case parsingFailed
    case genericError(String)
}
