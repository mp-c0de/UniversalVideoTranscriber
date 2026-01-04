//
//  PersistenceManager.swift
//  UniversalVideoTranscriber
//
//  Handles saving and loading transcription data
//

import Foundation

class PersistenceManager {
    static let shared = PersistenceManager()
    
    private let transcriptionsDirectory: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        transcriptionsDirectory = appSupport.appendingPathComponent("UniversalVideoTranscriber/Transcriptions")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: transcriptionsDirectory, withIntermediateDirectories: true)
    }
    
    func save(transcription: TranscriptionData) throws {
        // Check for duplicates using contentHash
        if let hash = transcription.contentHash, isSaved(contentHash: hash) {
            print("💾 [PERSISTENCE] Transcription already saved (hash: \(hash)), skipping duplicate save")
            return
        }

        let fileName = transcription.videoURL.lastPathComponent + "_" + UUID().uuidString + ".json"
        let fileURL = transcriptionsDirectory.appendingPathComponent(fileName)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(transcription)
        try data.write(to: fileURL)

        print("💾 [PERSISTENCE] Transcription saved successfully to: \(fileName)")
    }

    /// Check if a transcription with the given contentHash already exists
    func isSaved(contentHash: String) -> Bool {
        let existing = loadAll()
        return existing.contains { existingTranscription in
            existingTranscription.contentHash == contentHash
        }
    }
    
    func loadAll() -> [TranscriptionData] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: transcriptionsDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        
        return files.compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  let transcription = try? JSONDecoder().decode(TranscriptionData.self, from: data) else {
                return nil
            }
            return transcription
        }
    }
    
    func exportToTextFile(transcription: TranscriptionData, to url: URL) throws {
        var text = "Lithuanian Video Transcription\n"
        text += "Video: \(transcription.videoURL.lastPathComponent)\n"
        text += "Created: \(transcription.createdAt.formatted())\n"
        text += "Duration: \(formatDuration(transcription.videoDuration))\n"
        text += "\n" + String(repeating: "=", count: 60) + "\n\n"
        
        for item in transcription.items {
            text += "[\(item.formattedTimestamp)] \(item.text)\n"
        }
        
        try text.write(to: url, atomically: true, encoding: .utf8)
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
