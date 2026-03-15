import Foundation

enum BitBuddyBackendFactory {
    static func makeBackend() -> BitBuddyBackend {
        let foundationBackend = FoundationModelsBitBuddyService.shared
        if foundationBackend.isAvailable {
            return foundationBackend
        }
        return LocalFallbackBitBuddyService.shared
    }
}
