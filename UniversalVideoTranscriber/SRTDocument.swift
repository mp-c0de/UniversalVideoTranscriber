//
//  SRTDocument.swift
//  UniversalVideoTranscriber
//
//  FileDocument wrapper for exporting SRT subtitle files
//

import SwiftUI
import UniformTypeIdentifiers

struct SRTDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.srt] }

    var srtContent: String

    init(transcription: TranscriptionData?, characterLimit: Int = 42) {
        guard let transcription = transcription else {
            self.srtContent = ""
            return
        }

        self.srtContent = SRTExporter.export(
            items: transcription.items,
            characterLimit: characterLimit
        )
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        srtContent = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = srtContent.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
}

// Extend UTType to support SRT files
extension UTType {
    static var srt: UTType {
        UTType(exportedAs: "org.matroska.mks.subtitle", conformingTo: .plainText)
    }
}
