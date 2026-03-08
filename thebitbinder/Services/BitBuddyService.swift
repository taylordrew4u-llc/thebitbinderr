//
//  BitBuddyService.swift
//  thebitbinder
//
//  Created by Taylor Drew on 2/18/26.
//

import Foundation
import AVFoundation

/// BitBuddy — Your comedy writing AI assistant
/// Helps comedians fact-check, find alternative words, brainstorm punchlines,
/// and answer any question that helps create better jokes.
class BitBuddyService: NSObject, ObservableObject {
    
    static let shared = BitBuddyService()
    
    // MARK: - Configuration
    private let deepSeekAPI = "https://api.deepseek.com/chat/completions"
    let apiKey = "sk-668d8403e44e4e7ba36d8f053370790f"
    let agentId = "deepseek-chat"
    
    // MARK: - System Prompt
    private let systemPrompt = """
    You are BitBuddy, a comedy writing assistant. Help comedians by:
    1. Fact-checking claims, stats, and references
    2. Suggesting funnier words, synonyms, better phrasing
    3. Brainstorming punchlines, callbacks, tags
    4. Answering questions that help craft jokes
    Keep responses concise and fun. English only.
    """
    
    // MARK: - Dependencies
    private let authService = AuthService.shared
    
    // MARK: - State
    @Published var isLoading = false
    @Published var isConnected = false
    
    private var conversationId: String?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public API
    
    /// Send a text message and get a response from the agent
    func sendMessage(_ message: String) async throws -> String {
        // Check free usage limit before calling API
        try FreeUsageTracker.shared.consumeUse(for: .chat)
        
        // Ensure anonymous sign-in before making API calls
        try await authService.ensureAuthenticated()
        await MainActor.run {
            isLoading = true
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        print("🤖 [BitBuddy] Sending message: \(message)")
        
        do {
            let response = try await callDeepSeekAPI(message)
            print("🤖 [BitBuddy] Received response: \(response)")
            return response
        } catch {
            print("❌ [BitBuddy] Error: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Start a new conversation
    func startNewConversation() {
        conversationId = nil
        isConnected = false
    }
    
    // MARK: - DeepSeek API Methods
    
    private func callDeepSeekAPI(_ message: String) async throws -> String {
        guard let url = URL(string: deepSeekAPI) else {
            print("❌ [BitBuddy] Invalid URL")
            throw BitBuddyError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60
        
        let body: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": message]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("🤖 [BitBuddy] Sending request...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [BitBuddy] Invalid response type")
            throw BitBuddyError.invalidResponse
        }
        
        let responseString = String(data: data, encoding: .utf8) ?? "No data"
        print("🤖 [BitBuddy] Response Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            await MainActor.run {
                isConnected = true
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content
            }
            
            throw BitBuddyError.parseError
        } else if httpResponse.statusCode == 429 {
            throw BitBuddyError.apiError(statusCode: 429, message: "API quota exceeded.")
        } else if httpResponse.statusCode == 401 {
            throw BitBuddyError.apiError(statusCode: 401, message: "Invalid API key")
        }
        
        print("❌ [BitBuddy] HTTP Error \(httpResponse.statusCode): \(responseString)")
        throw BitBuddyError.apiError(statusCode: httpResponse.statusCode, message: responseString)
    }
    
    // MARK: - Audio Recording/Playback
    // Use weak-like cleanup pattern to free memory
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordedAudioURL: URL? = nil
    
    /// Clean up audio resources to free memory
    func cleanupAudioResources() {
        audioRecorder?.stop()
        audioRecorder = nil
        audioPlayer?.stop()
        audioPlayer = nil
        if let url = recordedAudioURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordedAudioURL = nil
    }
    
    /// Start recording audio from the microphone
    func startRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("bitbuddy_recording.m4a")
        recordedAudioURL = fileURL
        
        audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.record()
    }
    
    /// Stop recording and return the file URL
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        let url = recordedAudioURL
        recordedAudioURL = nil
        return url
    }
    
    /// Play audio from a given URL
    func playAudio(from url: URL) throws {
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
    }
    
    /// Play audio from Data
    func playAudio(data: Data) throws {
        audioPlayer = try AVAudioPlayer(data: data)
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
    }
    
    /// Send recorded audio to the agent and get a response
    func sendAudio(_ audioURL: URL) async throws -> String {
        // Check free usage limit before calling API
        try FreeUsageTracker.shared.consumeUse(for: .chat)
        
        // Ensure anonymous sign-in before making API calls
        try await authService.ensureAuthenticated()
        
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }
        
        guard (try? Data(contentsOf: audioURL)) != nil else {
            throw BitBuddyError.invalidResponse
        }

        print("🤖 [BitBuddy] Sending audio message as text...")
        let response = try await sendMessage("User sent an audio message")
        return response
    }
    
    // MARK: - Joke Extraction (consolidated from AIJokeExtractionService)
    
    /// Extract jokes from raw text using AI analysis
    /// Returns an array of individual jokes separated by AI understanding
    func extractJokes(from text: String) async throws -> [String] {
        try FreeUsageTracker.shared.consumeUse(for: .jokeExtract)
        try await authService.ensureAuthenticated()
        
        print("🤖 [AI Extract] Starting AI-powered extraction from \(text.count) chars...")
        
        guard !text.isEmpty else {
            print("❌ [AI Extract] Empty text")
            return []
        }
        
        let prompt = """
        You are an expert at identifying and separating individual jokes from text.
        
        Analyze this text which contains jokes. Your task is to:
        1. Identify each individual joke
        2. Separate them clearly
        3. Return ONLY a JSON array with the jokes
        
        Important:
        - Each joke should be complete and standalone
        - Remove any list markers (1., 2., -, •, etc.)
        - Preserve the joke content exactly
        - If a joke spans multiple lines, keep it together
        - Ignore any non-joke text
        
        Text to analyze:
        \"\"\"
        \(text)
        \"\"\"
        
        Return ONLY valid JSON array format, no other text:
        ["joke1", "joke2", "joke3", ...]
        """
        
        let response = try await callDeepSeekAPI(prompt)
        let jokes = try parseJokesFromResponse(response)
        
        print("🤖 [AI Extract] Found \(jokes.count) jokes via AI")
        for (idx, joke) in jokes.enumerated() {
            print("🤖 [AI Extract] Joke \(idx + 1): \(joke.prefix(50))...")
        }
        
        return jokes
    }
    
    // MARK: - Joke Categorization (consolidated from JokeCategorizationService)
    
    /// Analyze a single joke and return category, tags, difficulty, and humor rating
    func analyzeJoke(_ jokeText: String) async throws -> JokeAnalysis {
        try FreeUsageTracker.shared.consumeUse(for: .jokeAnalysis)
        try await authService.ensureAuthenticated()
        
        print("🎭 [Joke Analysis] Analyzing: \(jokeText.prefix(50))...")
        
        let prompt = """
        Analyze this joke and provide:
        1. A main category (Setup/Punchline joke, One-liner, Observational, Wordplay, Dark humor, Absurdist, etc.)
        2. Up to 3 relevant tags (funny words or themes in the joke)
        3. A difficulty rating (Easy, Medium, Hard - based on how well-structured it is)
        4. A humor rating (1-10)
        
        Joke: "\(jokeText)"
        
        Respond ONLY with valid JSON in this exact format:
        {
          "category": "category name",
          "tags": ["tag1", "tag2", "tag3"],
          "difficulty": "Easy|Medium|Hard",
          "humorRating": 7
        }
        
        NO other text, ONLY valid JSON.
        """
        
        let response = try await callDeepSeekAPI(prompt)
        let analysis = try parseJokeAnalysis(response)
        print("🎭 [Joke Analysis] Category: \(analysis.category), Tags: \(analysis.tags)")
        return analysis
    }
    
    /// Analyze multiple jokes and group them by category
    /// Memory optimized with batch processing
    func analyzeMultipleJokes(_ jokes: [Joke]) async throws -> [String: [Joke]] {
        print("🎭 [Bulk Analysis] Analyzing \(jokes.count) jokes...")
        
        var categorized: [String: [Joke]] = [:]
        var processedCount = 0
        
        for joke in jokes {
            do {
                let analysis = try await analyzeJoke(joke.content)
                
                if categorized[analysis.category] == nil {
                    categorized[analysis.category] = []
                }
                
                let updatedJoke = Joke(content: joke.content, title: joke.title, folder: joke.folder)
                updatedJoke.category = analysis.category
                updatedJoke.tags = analysis.tags
                updatedJoke.difficulty = analysis.difficulty
                updatedJoke.humorRating = analysis.humorRating
                
                categorized[analysis.category]?.append(updatedJoke)
                processedCount += 1
                print("🎭 [Bulk Analysis] Processed \(processedCount)/\(jokes.count)")
            } catch {
                print("❌ [Joke Analysis] Error: \(error.localizedDescription)")
                continue
            }
        }
        
        print("🎭 [Bulk Analysis] Complete! \(categorized.count) categories")
        return categorized
    }
    
    /// Get organization suggestions for a set of jokes
    func getOrganizationSuggestions(for jokes: [Joke]) async throws -> String {
        try FreeUsageTracker.shared.consumeUse(for: .orgSuggestion)
        try await authService.ensureAuthenticated()
        
        let jokesList = jokes.map { "- \($0.content)" }.joined(separator: "\n")
        
        let prompt = """
        I have these jokes that I'm trying to organize for a comedy set:
        
        \(jokesList)
        
        Please suggest:
        1. Best order to perform these jokes
        2. Which jokes work well together
        3. Which jokes might have similar audiences
        4. Any potential redundancy or similar themes
        """
        
        return try await callDeepSeekAPI(prompt)
    }
    
    // MARK: - Private Parsing Helpers
    
    private func parseJokesFromResponse(_ response: String) throws -> [String] {
        let jsonString: String
        
        if let jsonStart = response.firstIndex(of: "["),
           let jsonEnd = response.lastIndex(of: "]") {
            jsonString = String(response[jsonStart...jsonEnd])
        } else {
            print("❌ [BitBuddy] No JSON array found in response")
            throw BitBuddyError.parseError
        }
        
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            print("❌ [BitBuddy] Failed to parse JSON array")
            throw BitBuddyError.parseError
        }
        
        let jokes = json
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count >= 5 }
        
        print("✅ [BitBuddy] Successfully parsed \(jokes.count) jokes")
        return jokes
    }
    
    private func parseJokeAnalysis(_ response: String) throws -> JokeAnalysis {
        let jsonString: String
        
        if let jsonStart = response.firstIndex(of: "{"),
           let jsonEnd = response.lastIndex(of: "}") {
            jsonString = String(response[jsonStart...jsonEnd])
        } else {
            throw BitBuddyError.parseError
        }
        
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BitBuddyError.parseError
        }
        
        guard let category = json["category"] as? String,
              let tags = json["tags"] as? [String],
              let difficulty = json["difficulty"] as? String,
              let humorRating = json["humorRating"] as? Int else {
            throw BitBuddyError.parseError
        }
        
        return JokeAnalysis(
            category: category,
            tags: tags,
            difficulty: difficulty,
            humorRating: humorRating
        )
    }
}

// MARK: - Models

struct JokeAnalysis {
    let category: String
    let tags: [String]
    let difficulty: String
    let humorRating: Int
}

// MARK: - Errors
enum BitBuddyError: LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case parseError
    case notConnected
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let statusCode, let message):
            return "API Error (\(statusCode)): \(message)"
        case .parseError:
            return "Failed to parse response"
        case .notConnected:
            return "Not connected to BitBuddy"
        }
    }
}

extension BitBuddyService: AVAudioRecorderDelegate {
    // AVAudioRecorderDelegate methods (if needed) can be implemented here
}

extension BitBuddyService: AVAudioPlayerDelegate {
    // AVAudioPlayerDelegate methods (if needed) can be implemented here
}
