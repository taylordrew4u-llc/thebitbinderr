import Foundation

/// Deterministic local fallback for structured import parsing.
/// Uses the same segmentation and assembly pipeline as the main local file import flow.
struct LocalJokeImportAIService: JokeImportAIService {
    private let segmentationEngine = JokeSegmentationEngine()
    private let assemblyService = JokeAssemblyService()
    
    func extractJokes(from text: String, pages: [PDFPageExtraction]?) async throws -> [ParsedJoke] {
        let fileName = "Imported Text"
        let segments: [StructuralSegment]
        if let pages, !pages.isEmpty {
            segments = pages.flatMap { page in
                segmentationEngine.segment(
                    text: page.text,
                    fileName: fileName,
                    pageNumber: page.pageNumber,
                    startingOrder: (page.pageNumber - 1) * 1000
                )
            }
        } else {
            segments = segmentationEngine.segment(text: text, fileName: fileName)
        }
        
        let batch = assemblyService.assembleBatch(from: segments, fileName: fileName)
        return batch.importedRecords.map {
            ParsedJoke(
                title: $0.title,
                premise: $0.body,
                punchline: nil,
                tags: $0.tags,
                notes: $0.notes,
                sourcePage: $0.sourcePage,
                confidenceScore: confidenceValue(for: $0.confidence),
                rawTextSpan: $0.rawSourceText
            )
        }
    }
    
    private func confidenceValue(for confidence: ParsingConfidence) -> Double {
        switch confidence {
        case .high: return 0.9
        case .medium: return 0.65
        case .low: return 0.35
        }
    }
}
