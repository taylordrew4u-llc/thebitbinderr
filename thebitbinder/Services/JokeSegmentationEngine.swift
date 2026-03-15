import Foundation

struct JokeSegmentationEngine {
    private let normalizationService = TextNormalizationService()
    
    func segment(text: String, fileName: String, pageNumber: Int? = nil, startingOrder: Int = 0) -> [StructuralSegment] {
        let normalized = normalizationService.normalize(text)
        let lines = normalized.components(separatedBy: "\n")
        var segments: [StructuralSegment] = []
        var currentLines: [String] = []
        var order = startingOrder
        
        func flush(boundaryBefore: ParsingConfidence, boundaryAfter: ParsingConfidence) {
            let joined = currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !joined.isEmpty else {
                currentLines.removeAll()
                return
            }
            let lineLengths = currentLines.map { $0.trimmingCharacters(in: .whitespaces).count }.filter { $0 > 0 }
            let avg = lineLengths.isEmpty ? joined.count : lineLengths.reduce(0, +) / lineLengths.count
            let firstNonEmpty = currentLines.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? joined
            let trimmedFirst = firstNonEmpty.trimmingCharacters(in: .whitespacesAndNewlines)
            let looksLikeHeading = looksLikeHeadingLine(trimmedFirst, nextLines: Array(currentLines.dropFirst()))
            let hasBullet = trimmedFirst.range(of: #"^[-•*]\s"#, options: .regularExpression) != nil
            let hasNumber = trimmedFirst.range(of: #"^\d+[\.)]\s"#, options: .regularExpression) != nil
            
            segments.append(
                StructuralSegment(
                    id: UUID(),
                    originalText: joined,
                    normalizedText: joined,
                    pageNumber: pageNumber,
                    orderIndex: order,
                    boundaryConfidenceBefore: boundaryBefore,
                    boundaryConfidenceAfter: boundaryAfter,
                    lineCount: currentLines.count,
                    averageLineLength: avg,
                    hasBulletPrefix: hasBullet,
                    hasNumberPrefix: hasNumber,
                    looksLikeHeading: looksLikeHeading,
                    isVeryShort: joined.split(whereSeparator: \ .isWhitespace).count <= 5
                )
            )
            order += 1
            currentLines.removeAll()
        }
        
        for (index, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            let nextLine = index + 1 < lines.count ? lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
            
            if line.isEmpty {
                if !currentLines.isEmpty {
                    flush(boundaryBefore: .high, boundaryAfter: .high)
                }
                continue
            }
            
            let currentLooksLikeBoundary = isStrongBoundary(line: line, nextLine: nextLine)
            let currentIsStandalone = isStandaloneFragment(line)
            
            if !currentLines.isEmpty && (currentLooksLikeBoundary || currentIsStandalone) {
                flush(boundaryBefore: .medium, boundaryAfter: currentLooksLikeBoundary ? .high : .medium)
            }
            
            currentLines.append(line)
            
            if shouldEndAfter(line: line, nextLine: nextLine) {
                flush(boundaryBefore: .medium, boundaryAfter: boundaryConfidenceAfter(line: line, nextLine: nextLine))
            }
        }
        
        if !currentLines.isEmpty {
            flush(boundaryBefore: .medium, boundaryAfter: .low)
        }
        
        return segments
    }
    
    private func isStrongBoundary(line: String, nextLine: String) -> Bool {
        if line.range(of: #"^[-•*]\s"#, options: .regularExpression) != nil { return true }
        if line.range(of: #"^\d+[\.)]\s"#, options: .regularExpression) != nil { return true }
        if line.allSatisfy({ "-_*=#".contains($0) }) && line.count >= 3 { return true }
        if looksLikeHeadingLine(line, nextLines: nextLine.isEmpty ? [] : [nextLine]) { return true }
        return false
    }
    
    private func shouldEndAfter(line: String, nextLine: String) -> Bool {
        if nextLine.isEmpty { return true }
        if looksLikeHeadingLine(nextLine, nextLines: []) { return true }
        if nextLine.range(of: #"^[-•*]\s"#, options: .regularExpression) != nil { return true }
        if nextLine.range(of: #"^\d+[\.)]\s"#, options: .regularExpression) != nil { return true }
        if line.count <= 24 && nextLine.count > line.count + 25 { return true }
        return false
    }
    
    private func boundaryConfidenceAfter(line: String, nextLine: String) -> ParsingConfidence {
        if nextLine.isEmpty { return .high }
        if looksLikeHeadingLine(nextLine, nextLines: []) { return .high }
        if nextLine.range(of: #"^[-•*]\s"#, options: .regularExpression) != nil { return .high }
        if nextLine.range(of: #"^\d+[\.)]\s"#, options: .regularExpression) != nil { return .high }
        if line.count <= 18 || nextLine.count <= 18 { return .medium }
        return .low
    }
    
    private func isStandaloneFragment(_ line: String) -> Bool {
        let words = line.split(whereSeparator: \ .isWhitespace).count
        return words <= 5 && !line.hasSuffix(",") && !line.hasSuffix(";")
    }
    
    private func looksLikeHeadingLine(_ line: String, nextLines: [String]) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let words = trimmed.split(separator: " ")
        if trimmed.hasSuffix(":") && words.count <= 10 { return true }
        if words.count <= 8 && trimmed == trimmed.uppercased() && trimmed.rangeOfCharacter(from: .letters) != nil { return true }
        if words.count <= 8 && words.allSatisfy({ token in token.first?.isUppercase == true || token.count <= 3 }) && !nextLines.isEmpty {
            return true
        }
        return false
    }
}
