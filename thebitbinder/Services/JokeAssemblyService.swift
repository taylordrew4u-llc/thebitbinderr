import Foundation

struct JokeAssemblyService {
    private let titleDetector = TitleDetectionEngine()
    private let classifier = JokeClassificationEngine()
    private let tagExtractor = TagExtractionService()
    
    func assembleBatch(from segments: [StructuralSegment], fileName: String) -> ImportBatchResult {
        var importedRecords: [ImportedJokeRecord] = []
        var unresolvedFragments: [ImportedFragment] = []
        var orderedFragments: [ImportedFragment] = []
        var high = 0
        var medium = 0
        var low = 0
        
        for segment in segments {
            switch segment.boundaryConfidenceAfter {
            case .high: high += 1
            case .medium: medium += 1
            case .low: low += 1
            }
            
            let titleInfo = titleDetector.detectTitleCandidate(in: segment)
            let kind = classifier.classify(segment)
            let confidence = classifier.confidence(for: segment, kind: kind)
            let tags = tagExtractor.extractTags(from: segment.normalizedText)
            
            let sourceLocation = ImportSourceLocation(
                fileName: fileName,
                pageNumber: segment.pageNumber,
                orderIndex: segment.orderIndex
            )
            let flags = ImportParsingFlags(
                titleWasInferred: titleInfo.inferred,
                containsUnresolvedFragments: confidence == .low || kind == .unknown,
                ambiguousBoundaryBefore: segment.boundaryConfidenceBefore == .medium,
                ambiguousBoundaryAfter: segment.boundaryConfidenceAfter == .medium,
                originatedFromShortFragment: segment.isVeryShort
            )
            
            let fragment = ImportedFragment(
                id: UUID(),
                text: segment.originalText,
                normalizedText: segment.normalizedText,
                kind: kind,
                confidence: confidence,
                sourceLocation: sourceLocation,
                tags: tags,
                titleCandidate: titleInfo.title,
                parsingFlags: flags
            )
            orderedFragments.append(fragment)
            
            let generatedTitle = titleInfo.title ?? titleDetector.fallbackTitle(from: segment.normalizedText)
            let notes: String
            switch kind {
            case .note, .callbackReference:
                notes = segment.originalText
            case .ideaFragment, .unknown, .tag:
                notes = segment.originalText
            default:
                notes = ""
            }
            
            let body: String
            if let title = titleInfo.title, segment.normalizedText.hasPrefix(title), segment.normalizedText.count > title.count {
                body = segment.normalizedText
                    .replacingOccurrences(of: title, with: "", options: [.anchored])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                body = segment.normalizedText
            }
            
            let record = ImportedJokeRecord(
                id: UUID(),
                title: generatedTitle,
                body: body,
                rawSourceText: segment.originalText,
                notes: notes,
                tags: tags,
                confidence: confidence,
                sourceFilename: fileName,
                sourceOrder: segment.orderIndex,
                importTimestamp: Date(),
                parsingFlags: flags,
                unresolvedFragments: confidence == .low || kind == .unknown ? [fragment] : [],
                sourcePage: segment.pageNumber
            )
            importedRecords.append(record)
            
            if confidence == .low || kind == .unknown {
                unresolvedFragments.append(fragment)
            }
        }
        
        return ImportBatchResult(
            sourceFileName: fileName,
            importedRecords: importedRecords,
            unresolvedFragments: unresolvedFragments,
            orderedFragments: orderedFragments,
            stats: ImportBatchStats(
                totalSegments: segments.count,
                totalImportedRecords: importedRecords.count,
                unresolvedFragmentCount: unresolvedFragments.count,
                highConfidenceBoundaries: high,
                mediumConfidenceBoundaries: medium,
                lowConfidenceBoundaries: low
            ),
            importTimestamp: Date()
        )
    }
}
