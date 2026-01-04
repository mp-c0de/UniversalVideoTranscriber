//
//  TranscriptionManager.swift
//  UniversalVideoTranscriber
//
//  Manages audio extraction and Lithuanian transcription with chunking
//

import Foundation
import Speech
import AVFoundation

@MainActor
class TranscriptionManager: ObservableObject {
    @Published var transcriptItems: [TranscriptItem] = []
    @Published var isTranscribing = false
    @Published var transcriptionProgress: Double = 0.0
    @Published var statusMessage = ""
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var selectedLocale: Locale = Locale(identifier: "lt-LT")
    @Published var availableLocales: [Locale] = []
    @Published var assemblyAILanguage: String = "lt" // Default to Lithuanian

    private var speechRecognizer: SFSpeechRecognizer?
    private let chunkDuration: TimeInterval = 60.0 // 60 seconds per chunk for efficiency
    private let assemblyAIService = AssemblyAIService()
    private let whisperService = WhisperService.shared
    private let settings = SettingsManager.shared

    init() {
        // Get all available locales
        availableLocales = Array(SFSpeechRecognizer.supportedLocales()).sorted {
            $0.identifier < $1.identifier
        }

        // Try Lithuanian first, fallback to English (US) if not available
        if availableLocales.contains(where: { $0.identifier == "lt-LT" }) {
            selectedLocale = Locale(identifier: "lt-LT")
        } else {
            print("⚠️ WARNING: Lithuanian (lt-LT) is not supported by Apple Speech Recognition")
            print("Available locales: \(availableLocales.map { $0.identifier })")
            selectedLocale = Locale(identifier: "en-US")
        }

        speechRecognizer = SFSpeechRecognizer(locale: selectedLocale)
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()

        // Log status
        if let recognizer = speechRecognizer {
            print("Speech recognizer initialized for \(selectedLocale.identifier). Available: \(recognizer.isAvailable)")
        } else {
            print("Failed to initialize speech recognizer")
        }
    }

    func setLocale(_ locale: Locale) {
        selectedLocale = locale
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        print("Speech recognizer changed to \(locale.identifier)")
    }
    
    func requestAuthorization() async {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        authorizationStatus = status
    }
    
    func transcribe(videoURL: URL) async throws -> [TranscriptItem] {
        // Route to appropriate transcription service
        switch settings.transcriptionProvider {
        case .apple:
            return try await transcribeWithApple(videoURL: videoURL)
        case .assemblyAI:
            return try await transcribeWithAssemblyAI(videoURL: videoURL)
        case .whisper:
            return try await transcribeWithWhisper(videoURL: videoURL)
        }
    }

    // MARK: - Apple Speech Recognition

    private func transcribeWithApple(videoURL: URL) async throws -> [TranscriptItem] {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("ERROR: Speech recognizer not available")
            print("Recognizer exists: \(speechRecognizer != nil)")
            print("Is available: \(speechRecognizer?.isAvailable ?? false)")
            throw TranscriptionError.recognizerUnavailable
        }

        guard authorizationStatus == .authorized else {
            throw TranscriptionError.notAuthorized
        }

        // Reset progress to 0 at the start
        transcriptionProgress = 0.0
        isTranscribing = true
        transcriptItems = []
        statusMessage = "Extracting audio from video..."

        // Start accessing security scoped resource
        let accessingResource = videoURL.startAccessingSecurityScopedResource()
        defer {
            if accessingResource {
                videoURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            // Extract audio from video
            let audioURL = try await extractAudio(from: videoURL)
            
            // Get audio duration
            let asset = AVURLAsset(url: audioURL)
            let duration = try await asset.load(.duration).seconds
            
            statusMessage = "Transcribing audio (Duration: \(formatDuration(duration)))..."
            
            // Process audio in chunks
            let chunks = calculateChunks(duration: duration)
            var allItems: [TranscriptItem] = []
            
            for (index, chunk) in chunks.enumerated() {
                transcriptionProgress = Double(index) / Double(chunks.count)
                statusMessage = "Transcribing chunk \(index + 1) of \(chunks.count)..."
                
                let chunkItems = try await transcribeChunk(
                    audioURL: audioURL,
                    startTime: chunk.start,
                    duration: chunk.duration,
                    recognizer: recognizer
                )
                
                allItems.append(contentsOf: chunkItems)
            }
            
            transcriptionProgress = 1.0
            statusMessage = "Transcription complete! (\(allItems.count) segments)"
            transcriptItems = allItems
            
            // Clean up temporary audio file
            try? FileManager.default.removeItem(at: audioURL)
            
            isTranscribing = false
            return allItems

        } catch {
            isTranscribing = false
            transcriptionProgress = 0.0
            statusMessage = "Error: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - AssemblyAI Transcription

    private func transcribeWithAssemblyAI(videoURL: URL) async throws -> [TranscriptItem] {
        // Reset progress to 0 at the start
        transcriptionProgress = 0.0
        isTranscribing = true
        transcriptItems = []
        statusMessage = "Preparing audio for AssemblyAI..."

        // Start accessing security scoped resource
        let accessingResource = videoURL.startAccessingSecurityScopedResource()
        defer {
            if accessingResource {
                videoURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            // Extract audio from video
            let audioURL = try await extractAudio(from: videoURL)

            statusMessage = "Uploading to AssemblyAI..."

            // Use AssemblyAI service with progress callback
            let items = try await assemblyAIService.transcribe(
                audioURL: audioURL,
                languageCode: assemblyAILanguage,
                apiKey: settings.assemblyAIAPIKey,
                onProgress: { [weak self] progress, message in
                    self?.transcriptionProgress = progress
                    self?.statusMessage = message
                }
            )

            transcriptItems = items

            // Clean up temporary audio file
            try? FileManager.default.removeItem(at: audioURL)

            isTranscribing = false
            return items

        } catch {
            isTranscribing = false
            transcriptionProgress = 0.0
            statusMessage = "Error: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Whisper Transcription

    private func transcribeWithWhisper(videoURL: URL) async throws -> [TranscriptItem] {
        // Reset progress to 0 at the start
        transcriptionProgress = 0.0
        isTranscribing = true
        transcriptItems = []
        statusMessage = "Preparing audio for Whisper..."

        // Start accessing security scoped resource
        let accessingResource = videoURL.startAccessingSecurityScopedResource()
        defer {
            if accessingResource {
                videoURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            // Extract audio from video
            let audioURL = try await extractAudio(from: videoURL)

            statusMessage = "Running Whisper..."

            // Use Whisper service with selected language and progress callback
            let languageCode = assemblyAILanguage // Reuse the same language selection
            let items = try await whisperService.transcribe(
                audioURL: audioURL,
                language: languageCode,
                onProgress: { [weak self] progress, message in
                    self?.transcriptionProgress = progress
                    self?.statusMessage = message
                }
            )

            transcriptItems = items

            // Clean up temporary audio file
            try? FileManager.default.removeItem(at: audioURL)

            isTranscribing = false
            return items

        } catch {
            isTranscribing = false
            transcriptionProgress = 0.0
            statusMessage = "Error: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Audio Extraction (Shared)

    private func extractAudio(from videoURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)

        // Check if audio track exists
        guard try await !asset.loadTracks(withMediaType: .audio).isEmpty else {
            throw TranscriptionError.noAudioTrack
        }
        
        // Create export session
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw TranscriptionError.exportFailed
        }
        
        // Set output URL
        let tempDirectory = FileManager.default.temporaryDirectory
        let audioURL = tempDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        
        exportSession.outputURL = audioURL
        exportSession.outputFileType = .m4a

        try await exportSession.export(to: audioURL, as: .m4a)

        return audioURL
    }
    
    private func calculateChunks(duration: TimeInterval) -> [(start: TimeInterval, duration: TimeInterval)] {
        var chunks: [(TimeInterval, TimeInterval)] = []
        var currentTime: TimeInterval = 0
        
        while currentTime < duration {
            let remainingTime = duration - currentTime
            let chunkDuration = min(self.chunkDuration, remainingTime)
            chunks.append((currentTime, chunkDuration))
            currentTime += chunkDuration
        }
        
        return chunks
    }
    
    private func transcribeChunk(
        audioURL: URL,
        startTime: TimeInterval,
        duration: TimeInterval,
        recognizer: SFSpeechRecognizer
    ) async throws -> [TranscriptItem] {

        return try await withCheckedThrowingContinuation { continuation in
            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.shouldReportPartialResults = false
            request.requiresOnDeviceRecognition = false

            var items: [TranscriptItem] = []

            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                if let result = result {
                    if result.isFinal {
                        let segments = result.bestTranscription.segments

                        if segments.isEmpty && !result.bestTranscription.formattedString.isEmpty {
                            let item = TranscriptItem(
                                text: result.bestTranscription.formattedString,
                                timestamp: startTime,
                                confidence: 1.0
                            )
                            items.append(item)
                        } else {
                            items = self.groupSegmentsIntoSentences(segments: segments, startTime: startTime)
                        }

                        continuation.resume(returning: items)
                    }
                }
            }
        }
    }

    private func groupSegmentsIntoSentences(segments: [SFTranscriptionSegment], startTime: TimeInterval) -> [TranscriptItem] {
        var items: [TranscriptItem] = []
        var currentText = ""
        var currentStart: TimeInterval = 0
        var wordCount = 0
        var totalConfidence: Float = 0.0

        for (index, segment) in segments.enumerated() {
            if wordCount == 0 {
                currentStart = startTime + segment.timestamp
            }

            currentText += segment.substring + " "
            totalConfidence += segment.confidence
            wordCount += 1

            let isEndOfSentence = segment.substring.hasSuffix(".") ||
                                 segment.substring.hasSuffix("!") ||
                                 segment.substring.hasSuffix("?")
            let shouldBreak = wordCount >= 10 || isEndOfSentence || index == segments.count - 1

            if shouldBreak {
                let avgConfidence = wordCount > 0 ? totalConfidence / Float(wordCount) : 1.0
                let item = TranscriptItem(
                    text: currentText.trimmingCharacters(in: .whitespaces),
                    timestamp: currentStart,
                    confidence: avgConfidence
                )
                items.append(item)

                currentText = ""
                wordCount = 0
                totalConfidence = 0.0
            }
        }

        return items
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

enum TranscriptionError: LocalizedError {
    case recognizerUnavailable
    case notAuthorized
    case noAudioTrack
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return """
            Speech recogniser is not available for the selected language.

            ⚠️ IMPORTANT: Lithuanian is NOT supported by Apple Speech Recognition.
            Please select a different language from the dropdown menu in the toolbar.

            Supported languages include: English, Spanish, French, German, Italian, Portuguese, Chinese, Japanese, Korean, and many others.
            """
        case .notAuthorized:
            return "Speech recognition is not authorised. Please grant permission in System Settings."
        case .noAudioTrack:
            return "Video does not contain an audio track"
        case .exportFailed:
            return "Failed to extract audio from video"
        }
    }
}
