//
//  AssemblyAIService.swift
//  UniversalVideoTranscriber
//
//  AssemblyAI cloud transcription service for Lithuanian support
//

import Foundation
import AVFoundation

// Transcript result structure
struct TranscriptResult: Codable {
    let status: String
    let text: String?
    let words: [Word]?
    let error: String?

    struct Word: Codable {
        let text: String
        let start: Int
        let end: Int
        let confidence: Double
    }
}

@MainActor
class AssemblyAIService: ObservableObject {
    @Published var isTranscribing = false
    @Published var progress: Double = 0.0
    @Published var statusMessage = ""

    private let uploadEndpoint = "https://api.assemblyai.com/v2/upload"
    private let transcriptEndpoint = "https://api.assemblyai.com/v2/transcript"

    // Supported languages by AssemblyAI (including Lithuanian)
    static let supportedLanguages: [String: String] = [
        "en": "English (Global)",
        "es": "Spanish",
        "fr": "French",
        "de": "German",
        "it": "Italian",
        "pt": "Portuguese",
        "nl": "Dutch",
        "hi": "Hindi",
        "ja": "Japanese",
        "zh": "Chinese",
        "fi": "Finnish",
        "ko": "Korean",
        "pl": "Polish",
        "ru": "Russian",
        "tr": "Turkish",
        "uk": "Ukrainian",
        "vi": "Vietnamese",
        "lt": "Lithuanian 🇱🇹"  // Lithuanian support!
    ]

    func transcribe(
        audioURL: URL,
        languageCode: String,
        apiKey: String,
        onProgress: @escaping @MainActor (Double, String) async -> Void
    ) async throws -> [TranscriptItem] {
        guard !apiKey.isEmpty else {
            throw AssemblyAIError.missingAPIKey
        }

        isTranscribing = true
        statusMessage = "Uploading audio to AssemblyAI..."
        progress = 0.1
        await onProgress(0.1, "Uploading audio to AssemblyAI...")

        do {
            // Step 1: Upload audio file
            let uploadURL = try await uploadAudio(audioURL: audioURL, apiKey: apiKey)

            statusMessage = "Starting transcription..."
            progress = 0.3
            await onProgress(0.3, "Starting transcription...")

            // Step 2: Request transcription
            let transcriptID = try await requestTranscription(audioURL: uploadURL, languageCode: languageCode, apiKey: apiKey)

            statusMessage = "Processing transcription..."
            progress = 0.5
            await onProgress(0.5, "Processing transcription...")

            // Step 3: Poll for results
            let transcript = try await pollTranscription(transcriptID: transcriptID, apiKey: apiKey, onProgress: onProgress)

            statusMessage = "Conversion complete!"
            progress = 1.0
            await onProgress(1.0, "Conversion complete!")

            isTranscribing = false
            return transcript
        } catch {
            isTranscribing = false
            progress = 0.0
            throw error
        }
    }

    private func uploadAudio(audioURL: URL, apiKey: String) async throws -> String {
        var request = URLRequest(url: URL(string: uploadEndpoint)!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        let audioData = try Data(contentsOf: audioURL)
        request.httpBody = audioData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AssemblyAIError.uploadFailed
        }

        struct UploadResponse: Codable {
            let upload_url: String
        }

        let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
        return uploadResponse.upload_url
    }

    private func requestTranscription(audioURL: String, languageCode: String, apiKey: String) async throws -> String {
        var request = URLRequest(url: URL(string: transcriptEndpoint)!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct TranscriptRequest: Codable {
            let audio_url: String
            let language_code: String
        }

        let transcriptRequest = TranscriptRequest(audio_url: audioURL, language_code: languageCode)
        request.httpBody = try JSONEncoder().encode(transcriptRequest)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AssemblyAIError.transcriptionFailed
        }

        struct TranscriptResponse: Codable {
            let id: String
        }

        let transcriptResponse = try JSONDecoder().decode(TranscriptResponse.self, from: data)
        return transcriptResponse.id
    }

    private func pollTranscription(
        transcriptID: String,
        apiKey: String,
        onProgress: @escaping @MainActor (Double, String) async -> Void
    ) async throws -> [TranscriptItem] {
        let pollURL = URL(string: "\(transcriptEndpoint)/\(transcriptID)")!
        var request = URLRequest(url: pollURL)
        request.setValue(apiKey, forHTTPHeaderField: "authorization")

        var pollCount = 0
        let maxPolls = 60

        // Poll every 3 seconds until completed
        while true {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw AssemblyAIError.pollingFailed
            }

            let result = try JSONDecoder().decode(TranscriptResult.self, from: data)

            switch result.status {
            case "completed":
                // Convert words to TranscriptItems
                guard let words = result.words else {
                    throw AssemblyAIError.noTranscriptData
                }

                // Group words into sentences (every 10 words or at punctuation)
                return groupWordsIntoSegments(words: words)

            case "error":
                throw AssemblyAIError.transcriptionFailed

            case "processing", "queued":
                // Update progress based on polling iterations
                pollCount += 1
                let estimatedProgress = 0.5 + (Double(pollCount) / Double(maxPolls) * 0.4)
                let currentProgress = min(estimatedProgress, 0.95)
                let message = "Processing: \(result.status)... (\(Int(currentProgress * 100))%)"

                await MainActor.run {
                    progress = currentProgress
                    statusMessage = message
                }
                await onProgress(currentProgress, message)

                try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                continue

            default:
                pollCount += 1
                let estimatedProgress = 0.5 + (Double(pollCount) / Double(maxPolls) * 0.4)
                let currentProgress = min(estimatedProgress, 0.95)
                let message = "Processing..."

                await MainActor.run {
                    progress = currentProgress
                    statusMessage = message
                }
                await onProgress(currentProgress, message)

                try await Task.sleep(nanoseconds: 3_000_000_000)
                continue
            }
        }
    }

    private func groupWordsIntoSegments(words: [TranscriptResult.Word]) -> [TranscriptItem] {
        var items: [TranscriptItem] = []
        var currentText = ""
        var currentStart: TimeInterval = 0
        var wordCount = 0

        for (index, word) in words.enumerated() {
            if wordCount == 0 {
                currentStart = Double(word.start) / 1000.0 // Convert ms to seconds
            }

            currentText += word.text + " "
            wordCount += 1

            // Create segment every 10 words or at sentence end
            let isEndOfSentence = word.text.hasSuffix(".") || word.text.hasSuffix("!") || word.text.hasSuffix("?")
            let shouldBreak = wordCount >= 10 || isEndOfSentence || index == words.count - 1

            if shouldBreak {
                let item = TranscriptItem(
                    text: currentText.trimmingCharacters(in: .whitespaces),
                    timestamp: currentStart,
                    confidence: Float(word.confidence)
                )
                items.append(item)

                currentText = ""
                wordCount = 0
            }
        }

        return items
    }
}

enum AssemblyAIError: LocalizedError {
    case missingAPIKey
    case uploadFailed
    case transcriptionFailed
    case pollingFailed
    case noTranscriptData

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "AssemblyAI API key is missing. Please add your API key in Settings."
        case .uploadFailed:
            return "Failed to upload audio file to AssemblyAI. Check your internet connection."
        case .transcriptionFailed:
            return "Transcription request failed. Please check your API key and try again."
        case .pollingFailed:
            return "Failed to retrieve transcription results."
        case .noTranscriptData:
            return "No transcript data was returned from AssemblyAI."
        }
    }
}
