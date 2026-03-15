import Foundation

enum ParsingConfidence: String, Codable, Sendable {
    case low
    case medium
    case high
}

enum ImportExtractionMethod: String, Codable, Sendable {
    case pdfKit
    case visionOCR
    case plainText
    case attributedDocument
    case imageOCR
    case unknown
}

enum ImportedFragmentKind: String, Codable, Sendable {
    case title
    case joke
    case premise
    case tag
    case setup
    case punchline
    case note
    case ideaFragment
    case callbackReference
    case unknown
}

struct ImportSourceLocation: Codable, Sendable {
    let fileName: String
    let pageNumber: Int?
    let orderIndex: Int
}

struct ImportParsingFlags: Codable, Sendable {
    let titleWasInferred: Bool
    let containsUnresolvedFragments: Bool
    let ambiguousBoundaryBefore: Bool
    let ambiguousBoundaryAfter: Bool
    let originatedFromShortFragment: Bool
}

struct ImportedFragment: Identifiable, Codable, Sendable {
    let id: UUID
    let text: String
    let normalizedText: String
    let kind: ImportedFragmentKind
    let confidence: ParsingConfidence
    let sourceLocation: ImportSourceLocation
    let tags: [String]
    let titleCandidate: String?
    let parsingFlags: ImportParsingFlags
}

struct ImportedJokeRecord: Identifiable, Codable, Sendable {
    let id: UUID
    let title: String
    let body: String
    let rawSourceText: String
    let notes: String
    let tags: [String]
    let confidence: ParsingConfidence
    let sourceFilename: String
    let sourceOrder: Int
    let importTimestamp: Date
    let parsingFlags: ImportParsingFlags
    let unresolvedFragments: [ImportedFragment]
    let sourcePage: Int?
}

struct ImportBatchStats: Codable, Sendable {
    let totalSegments: Int
    let totalImportedRecords: Int
    let unresolvedFragmentCount: Int
    let highConfidenceBoundaries: Int
    let mediumConfidenceBoundaries: Int
    let lowConfidenceBoundaries: Int
}

struct ImportBatchResult: Codable, Sendable {
    let sourceFileName: String
    let importedRecords: [ImportedJokeRecord]
    let unresolvedFragments: [ImportedFragment]
    let orderedFragments: [ImportedFragment]
    let stats: ImportBatchStats
    let importTimestamp: Date
}

struct StructuralSegment: Identifiable, Sendable {
    let id: UUID
    let originalText: String
    let normalizedText: String
    let pageNumber: Int?
    let orderIndex: Int
    let boundaryConfidenceBefore: ParsingConfidence
    let boundaryConfidenceAfter: ParsingConfidence
    let lineCount: Int
    let averageLineLength: Int
    let hasBulletPrefix: Bool
    let hasNumberPrefix: Bool
    let looksLikeHeading: Bool
    let isVeryShort: Bool
}
