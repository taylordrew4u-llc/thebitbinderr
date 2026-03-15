import Foundation

/*
 NOTE: This implementation is designed for Apple's on-device Foundation Models runtime.
 The service remains availability-gated so unsupported devices fall back to a deterministic
 local import pipeline instead of any external AI provider.
*/

class AppleFoundationModelsJokeImportService: JokeImportAIService {
    static var isAvailable: Bool {
        return false
    }
    
    func extractJokes(from text: String, pages: [PDFPageExtraction]? = nil) async throws -> [ParsedJoke] {
        print("🍏 [Apple AI] Extracting jokes from \(text.count) characters...")
        
        // TODO: Implement when the Foundation Models runtime is enabled in the app target.
        // The system and user prompts below define the intended preservation-first behavior.
        /*
        let systemPrompt = """
        You are analyzing imported stand-up comedy notes from a PDF and converting them into individual joke-book entries.
        Preserve the maximum number of joke ideas.
        Split aggressively when there are signs of separate joke ideas.
        Merge only when the text clearly belongs to the same joke.
        Preserve fragments, tags, alternate punchlines, and partial thoughts.
        Never discard text simply because it is short or incomplete.
        Return a JSON array of objects with keys:
        title, premise, punchline, tags, notes, sourcePage, confidenceScore, rawTextSpan
        """
        
        let userPrompt = "Text to parse:\n\n\"\"\"\n\(text)\n\"\"\""
        */
        
        throw JokeImportAIErrors.serviceUnavailable
    }
}
