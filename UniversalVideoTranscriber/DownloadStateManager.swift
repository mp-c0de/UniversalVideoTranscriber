//
//  DownloadStateManager.swift
//  UniversalVideoTranscriber
//
//  Global singleton to track Whisper model download state across all views
//

import Foundation

@MainActor
class DownloadStateManager: ObservableObject {
    static let shared = DownloadStateManager()

    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadingModel: WhisperService.WhisperModel?
    @Published var downloadError: String?
    @Published var statusMessage: String = ""

    private init() {}

    func startDownload(model: WhisperService.WhisperModel) {
        isDownloading = true
        downloadingModel = model
        downloadProgress = 0.0
        downloadError = nil
        statusMessage = "Starting download..."
    }

    func updateProgress(_ progress: Double, message: String) {
        downloadProgress = progress
        statusMessage = message
    }

    func completeDownload() {
        isDownloading = false
        downloadProgress = 1.0
        statusMessage = "Download complete"
        downloadingModel = nil
    }

    func failDownload(error: String) {
        isDownloading = false
        downloadError = error
        statusMessage = "Download failed"
        downloadingModel = nil
    }

    func resetState() {
        isDownloading = false
        downloadProgress = 0.0
        downloadingModel = nil
        downloadError = nil
        statusMessage = ""
    }
}
