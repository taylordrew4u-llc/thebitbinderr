import Foundation
import UIKit

final class FileImportService {
    static let shared = FileImportService()
    
    private let pdfExtractionService = PDFExtractionService.shared
    private let normalizationService = TextNormalizationService()
    private let segmentationEngine = JokeSegmentationEngine()
    private let assemblyService = JokeAssemblyService()
    
    private init() {}
    
    func importBatch(from url: URL) async throws -> ImportBatchResult {
        let fileName = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        
        switch ext {
        case "pdf":
            let extraction = try await pdfExtractionService.extractText(from: url)
            let segments = extraction.pages.flatMap { page in
                segmentationEngine.segment(
                    text: page.text,
                    fileName: fileName,
                    pageNumber: page.pageNumber,
                    startingOrder: (page.pageNumber - 1) * 1000
                )
            }
            return assemblyService.assembleBatch(from: segments, fileName: fileName)
        case "doc", "docx":
            if let attrString = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) {
                let segments = segmentationEngine.segment(text: attrString.string, fileName: fileName)
                return assemblyService.assembleBatch(from: segments, fileName: fileName)
            }
        case "jpg", "jpeg", "png", "heic", "heif", "tiff", "bmp", "gif":
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                let text = try await TextRecognitionService.recognizeText(from: image)
                let normalized = normalizationService.normalize(text)
                let segments = segmentationEngine.segment(text: normalized, fileName: fileName)
                return assemblyService.assembleBatch(from: segments, fileName: fileName)
            }
        default:
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                let normalized = normalizationService.normalize(text)
                let segments = segmentationEngine.segment(text: normalized, fileName: fileName)
                return assemblyService.assembleBatch(from: segments, fileName: fileName)
            }
            if let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .ascii) {
                let normalized = normalizationService.normalize(text)
                let segments = segmentationEngine.segment(text: normalized, fileName: fileName)
                return assemblyService.assembleBatch(from: segments, fileName: fileName)
            }
        }
        
        return ImportBatchResult(
            sourceFileName: fileName,
            importedRecords: [],
            unresolvedFragments: [],
            orderedFragments: [],
            stats: ImportBatchStats(
                totalSegments: 0,
                totalImportedRecords: 0,
                unresolvedFragmentCount: 0,
                highConfidenceBoundaries: 0,
                mediumConfidenceBoundaries: 0,
                lowConfidenceBoundaries: 0
            ),
            importTimestamp: Date()
        )
    }
}
