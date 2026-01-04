//
//  TranscriptItem.swift
//  UniversalVideoTranscriber
//
//  Data model for transcript segments
//

import Foundation

struct TranscriptItem: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let timestamp: TimeInterval
    let confidence: Float
    
    init(id: UUID = UUID(), text: String, timestamp: TimeInterval, confidence: Float = 1.0) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.confidence = confidence
    }
    
    var formattedTimestamp: String {
        let hours = Int(timestamp) / 3600
        let minutes = Int(timestamp) % 3600 / 60
        let seconds = Int(timestamp) % 60
        let milliseconds = Int((timestamp.truncatingRemainder(dividingBy: 1)) * 1000)
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
        } else {
            return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
        }
    }
}

struct TranscriptionData: Codable {
    let videoURL: URL
    let items: [TranscriptItem]
    let createdAt: Date
    let videoDuration: TimeInterval
    let transcriptionDuration: TimeInterval?
    let contentHash: String?  // Optional for backward compatibility with old saves

    init(videoURL: URL, items: [TranscriptItem], videoDuration: TimeInterval, transcriptionDuration: TimeInterval? = nil) {
        self.videoURL = videoURL
        self.items = items
        self.createdAt = Date()
        self.videoDuration = videoDuration
        self.transcriptionDuration = transcriptionDuration
        self.contentHash = Self.generateContentHash(videoURL: videoURL, items: items, videoDuration: videoDuration)
    }

    // Generate a unique hash based on video URL, item count, and first/last items
    private static func generateContentHash(videoURL: URL, items: [TranscriptItem], videoDuration: TimeInterval) -> String {
        var hasher = Hasher()
        hasher.combine(videoURL.lastPathComponent)
        hasher.combine(items.count)
        hasher.combine(videoDuration)

        // Include first and last items for better uniqueness
        if let first = items.first {
            hasher.combine(first.text)
            hasher.combine(first.timestamp)
        }
        if let last = items.last, items.count > 1 {
            hasher.combine(last.text)
            hasher.combine(last.timestamp)
        }

        return String(hasher.finalize())
    }

    var formattedTranscriptionDuration: String? {
        guard let duration = transcriptionDuration else { return nil }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)min \(seconds)sec"
        } else {
            return "\(seconds)sec"
        }
    }
}
