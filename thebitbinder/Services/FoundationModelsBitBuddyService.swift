import Foundation

/// Apple-native BitBuddy backend.
/// This is structured around an on-device, session-oriented chat model.
/// If the Foundation Models runtime isn't available, callers should use the local fallback backend.
final class FoundationModelsBitBuddyService: BitBuddyBackend {
    static let shared = FoundationModelsBitBuddyService()
    
    private init() {}
    
    var backendName: String { "Foundation Models" }
    var isAvailable: Bool {
        if #available(iOS 18.0, macOS 15.0, *) {
            return false
        }
        return false
    }
    var supportsStreaming: Bool { false }
    
    func send(
        message: String,
        session: BitBuddySessionSnapshot,
        dataContext: BitBuddyDataContext
    ) async throws -> String {
        guard isAvailable else {
            throw BitBuddyBackendError.unavailable
        }
        
        // TODO: Wire this to Apple's Foundation Models runtime when that framework is enabled
        // in the target. The service contract is already session-based and local-only.
        // The prompt below documents the intended app-specific behavior.
        let _ = buildPrompt(message: message, session: session, dataContext: dataContext)
        throw BitBuddyBackendError.unavailable
    }
    
    private func buildPrompt(
        message: String,
        session: BitBuddySessionSnapshot,
        dataContext: BitBuddyDataContext
    ) -> String {
        let recentTurns = session.turns.suffix(8).map { "\($0.role.rawValue): \($0.text)" }.joined(separator: "\n")
        let recentJokes = dataContext.recentJokes.prefix(5).map {
            "- \($0.title): \($0.content.prefix(180))"
        }.joined(separator: "\n")
        
        return """
        You are BitBuddy, an on-device comedy writing partner inside BitBinder.
        Be sharp, concise, collaborative, and useful.
        Help with setups, punchlines, tags, rewrites, structure, sequencing, and brainstorming.
        Do not act like a therapist or generic life coach.
        Do not invent facts or pretend to know user material you were not given.
        Prefer concrete rewrites, alternatives, and next-step suggestions.
        If app joke context is available, ground your response in it.
        
        Conversation so far:
        \(recentTurns)
        
        Recent jokes in the notebook:
        \(recentJokes.isEmpty ? "None provided." : recentJokes)
        
        Latest user message:
        \(message)
        """
    }
}
