//
//  SRTExporter.swift
//  UniversalVideoTranscriber
//
//  Service for exporting transcriptions to SRT subtitle format
//

import Foundation

class SRTExporter {
    /// Export transcript items to SRT format with optional character limit per line
    /// - Parameters:
    ///   - items: Array of TranscriptItem to export
    ///   - characterLimit: Maximum characters per line (default: 42)
    ///   - defaultDuration: Default duration for each subtitle if no next item (default: 2.0 seconds)
    /// - Returns: SRT formatted string ready to save to file
    static func export(items: [TranscriptItem], characterLimit: Int = 42, defaultDuration: TimeInterval = 2.0) -> String {
        var srtContent = ""

        for (index, item) in items.enumerated() {
            let sequenceNumber = index + 1
            let startTime = formatSRTTime(item.timestamp)

            // Calculate end time: use next item's timestamp, or add default duration for last item
            let endTime: String
            if index < items.count - 1 {
                endTime = formatSRTTime(items[index + 1].timestamp)
            } else {
                endTime = formatSRTTime(item.timestamp + defaultDuration)
            }

            // Split text into lines if it exceeds character limit
            let lines = splitTextIntoLines(item.text, maxChars: characterLimit)

            // Format SRT entry
            srtContent += "\(sequenceNumber)\n"
            srtContent += "\(startTime) --> \(endTime)\n"
            srtContent += lines.joined(separator: "\n")
            srtContent += "\n\n"
        }

        return srtContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Format TimeInterval to SRT timestamp format (HH:MM:SS,mmm)
    /// - Parameter seconds: Time in seconds
    /// - Returns: Formatted string like "00:01:23,456"
    private static func formatSRTTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        let milliseconds = Int((seconds.truncatingRemainder(dividingBy: 1)) * 1000)

        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, secs, milliseconds)
    }

    /// Split text into multiple lines based on character limit
    /// - Parameters:
    ///   - text: The text to split
    ///   - maxChars: Maximum characters per line
    /// - Returns: Array of text lines
    private static func splitTextIntoLines(_ text: String, maxChars: Int) -> [String] {
        // If text fits in one line, return as-is
        if text.count <= maxChars {
            return [text]
        }

        var lines: [String] = []
        var currentLine = ""
        let words = text.split(separator: " ")

        for word in words {
            let wordStr = String(word)
            let potentialLine = currentLine.isEmpty ? wordStr : currentLine + " " + wordStr

            if potentialLine.count <= maxChars {
                currentLine = potentialLine
            } else {
                // Current line is full, start new line
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                }

                // If single word exceeds limit, force it on its own line
                if wordStr.count > maxChars {
                    lines.append(wordStr)
                    currentLine = ""
                } else {
                    currentLine = wordStr
                }
            }
        }

        // Add remaining text
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }

        return lines
    }
}
