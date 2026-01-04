//
//  SettingsView.swift
//  UniversalVideoTranscriber
//
//  Settings panel for API keys and transcription provider
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var whisperService = WhisperService.shared
    @ObservedObject var downloadState = DownloadStateManager.shared
    @State private var showAPIKeyInstructions = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Transcription Provider Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Transcription Provider")
                            .font(.headline)

                        Picker("Provider", selection: $settings.transcriptionProvider) {
                            ForEach(SettingsManager.TranscriptionProvider.allCases, id: \.self) { provider in
                                Text(provider.displayName).tag(provider)
                            }
                        }
                        .pickerStyle(.radioGroup)

                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(settings.transcriptionProvider == .whisper ? .green : .blue)
                            Text(settings.transcriptionProvider.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 20)
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)

                    // AssemblyAI API Key Section
                    if settings.transcriptionProvider == .assemblyAI {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("AssemblyAI API Key")
                                    .font(.headline)
                                Spacer()
                                Button(action: { showAPIKeyInstructions.toggle() }) {
                                    Label("How to get API key", systemImage: "questionmark.circle")
                                        .font(.caption)
                                }
                                .buttonStyle(.link)
                            }

                            SecureField("Enter your AssemblyAI API key", text: $settings.assemblyAIAPIKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))

                            if settings.assemblyAIAPIKey.isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("API key required for AssemblyAI transcription")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("API key saved securely in Keychain")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            if showAPIKeyInstructions {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("To get your AssemblyAI API key:")
                                        .font(.caption)
                                        .fontWeight(.semibold)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("1. Visit assemblyai.com")
                                        Text("2. Sign up for a free account")
                                        Text("3. Go to your dashboard")
                                        Text("4. Copy your API key")
                                        Text("5. Paste it above")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                    Divider()

                                    HStack(spacing: 8) {
                                        Image(systemName: "gift.fill")
                                            .foregroundColor(.green)
                                        Text("Free tier: 5 hours of transcription per month")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Button(action: {
                                        if let url = URL(string: "https://www.assemblyai.com/") {
                                            NSWorkspace.shared.open(url)
                                        }
                                    }) {
                                        Label("Open AssemblyAI Website", systemImage: "arrow.up.forward.square")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.link)
                                }
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                    }

                    // Whisper Model Selection
                    if settings.transcriptionProvider == .whisper {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Whisper Model")
                                .font(.headline)

                            Picker("Model Size", selection: $settings.whisperModel) {
                                ForEach(WhisperService.WhisperModel.allCases, id: \.self) { model in
                                    Text(model.displayName).tag(model)
                                }
                            }
                            .pickerStyle(.radioGroup)
                            .onChange(of: settings.whisperModel) {
                                whisperService.checkModelAvailability()
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.blue)
                                    Text("Larger models are more accurate but slower")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Divider()

                                // Model download status
                                if whisperService.isModelDownloaded {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                            Text("Model downloaded and ready")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        Button(action: {
                                            do {
                                                try whisperService.deleteModel(model: settings.whisperModel)
                                            } catch {
                                                downloadState.downloadError = error.localizedDescription
                                            }
                                        }) {
                                            Label("Delete Model", systemImage: "trash.fill")
                                                .font(.caption)
                                        }
                                        .buttonStyle(.bordered)
                                        .foregroundColor(.red)
                                    }
                                } else {
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                        Text("Model not downloaded - click Download below")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Divider()

                                    // Download section
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("Download Size: \(settings.whisperModel.sizeEstimate)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        if downloadState.isDownloading {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(downloadState.statusMessage)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)

                                                ProgressView(value: downloadState.downloadProgress)
                                                    .progressViewStyle(.linear)

                                                Text("\(Int(downloadState.downloadProgress * 100))%")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        } else {
                                            Button(action: {
                                                Task {
                                                    do {
                                                        try await whisperService.downloadModel(model: settings.whisperModel)
                                                    } catch {
                                                        // Error already handled by DownloadStateManager
                                                    }
                                                }
                                            }) {
                                                Label("Download Model", systemImage: "arrow.down.circle.fill")
                                                    .font(.caption)
                                            }
                                            .buttonStyle(.borderedProminent)
                                        }

                                        if let error = downloadState.downloadError {
                                            HStack(spacing: 8) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.red)
                                                Text(error)
                                                    .font(.caption)
                                                    .foregroundColor(.red)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                    }

                    // Info Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(icon: "lock.fill", text: "API keys are stored securely in macOS Keychain")
                            InfoRow(icon: "network", text: "AssemblyAI requires internet connection")
                            InfoRow(icon: "dollarsign.circle", text: "AssemblyAI: Free 5 hours/month, then $0.00025/second")
                            InfoRow(icon: "star.fill", text: "Whisper: FREE forever, runs offline, self-contained")
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding()
            }
        }
        .frame(width: 600, height: 600)
    }
}

struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    SettingsView()
}
