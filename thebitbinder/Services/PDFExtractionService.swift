import Foundation
import PDFKit
import Vision

struct PDFPageExtraction {
    let text: String
    let pageNumber: Int
    let method: ExtractionMethod
    let hasSelectableText: Bool
    
    enum ExtractionMethod: String {
        case pdfKit = "PDFKit"
        case visionOCR = "Vision OCR"
    }
}

struct PDFExtractionResult {
    let fullText: String
    let pages: [PDFPageExtraction]
    let fileName: String
}

class PDFExtractionService {
    static let shared = PDFExtractionService()
    
    private init() {}
    
    func extractText(from url: URL) async throws -> PDFExtractionResult {
        guard let document = PDFDocument(url: url) else {
            throw PDFExtractionError.invalidDocument
        }
        
        var pages: [PDFPageExtraction] = []
        var fullText = ""
        
        let pageCount = document.pageCount
        for i in 0..<pageCount {
            guard let page = document.page(at: i) else { continue }
            let pageNumber = i + 1
            
            // Try PDFKit text extraction first
            let pdfKitText = page.string ?? ""
            let trimmedPdfKitText = pdfKitText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Detect if page has little or no selectable text
            // Threshold: if page has very few characters but visually might have text
            if trimmedPdfKitText.count > 50 {
                let extraction = PDFPageExtraction(
                    text: pdfKitText,
                    pageNumber: pageNumber,
                    method: .pdfKit,
                    hasSelectableText: true
                )
                pages.append(extraction)
                fullText += pdfKitText + "\n\n"
            } else {
                // Fallback to Vision OCR for scanned or image-based pages
                print("📄 PDF: Page \(pageNumber) has little selectable text, using Vision OCR")
                
                // Convert PDF page to image for OCR
                if let image = pageToImage(page) {
                    do {
                        let ocrText = try await TextRecognitionService.recognizeText(from: image)
                        let extraction = PDFPageExtraction(
                            text: ocrText,
                            pageNumber: pageNumber,
                            method: .visionOCR,
                            hasSelectableText: false
                        )
                        pages.append(extraction)
                        fullText += ocrText + "\n\n"
                    } catch {
                        print("❌ PDF: OCR failed on page \(pageNumber): \(error)")
                        // Even if OCR fails, keep the (possibly empty) PDFKit text to preserve page count
                        let extraction = PDFPageExtraction(
                            text: pdfKitText,
                            pageNumber: pageNumber,
                            method: .pdfKit,
                            hasSelectableText: false
                        )
                        pages.append(extraction)
                        fullText += pdfKitText + "\n\n"
                    }
                } else {
                    let extraction = PDFPageExtraction(
                        text: pdfKitText,
                        pageNumber: pageNumber,
                        method: .pdfKit,
                        hasSelectableText: false
                    )
                    pages.append(extraction)
                    fullText += pdfKitText + "\n\n"
                }
            }
        }
        
        return PDFExtractionResult(
            fullText: fullText,
            pages: pages,
            fileName: url.lastPathComponent
        )
    }
    
    private func pageToImage(_ page: PDFPage) -> UIImage? {
        let pageSize = page.bounds(for: .mediaBox).size
        let renderer = UIGraphicsImageRenderer(size: pageSize)
        let image = renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(CGRect(origin: .zero, size: pageSize))
            ctx.cgContext.translateBy(x: 0, y: pageSize.height)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
        return image
    }
}

enum PDFExtractionError: Error {
    case invalidDocument
}
