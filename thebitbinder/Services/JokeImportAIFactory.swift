import Foundation

enum JokeImportAIFactory {
    static func getService() -> JokeImportAIService {
        if AppleFoundationModelsJokeImportService.isAvailable {
            return AppleFoundationModelsJokeImportService()
        }
        return LocalJokeImportAIService()
    }
}
