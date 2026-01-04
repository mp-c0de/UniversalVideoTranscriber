//
//  SettingsManager.swift
//  UniversalVideoTranscriber
//
//  Manages app settings and API keys
//

import Foundation
import Security

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var assemblyAIAPIKey: String {
        didSet {
            saveAPIKey(assemblyAIAPIKey)
        }
    }

    @Published var transcriptionProvider: TranscriptionProvider {
        didSet {
            UserDefaults.standard.set(transcriptionProvider.rawValue, forKey: "transcriptionProvider")
        }
    }

    enum TranscriptionProvider: String, CaseIterable {
        case apple = "Apple Speech Recognition (Free, No Lithuanian)"
        case assemblyAI = "AssemblyAI (Paid, Lithuanian Support)"
        case whisper = "Whisper (FREE Lithuanian!) ⭐️"

        var displayName: String {
            return self.rawValue
        }

        var description: String {
            switch self {
            case .apple:
                return "Free • 60+ languages • No Lithuanian • Fast"
            case .assemblyAI:
                return "Paid • Lithuanian supported • Cloud-based • Very accurate"
            case .whisper:
                return "FREE • Lithuanian supported • Offline • Open source"
            }
        }
    }

    @Published var whisperModel: WhisperService.WhisperModel {
        didSet {
            UserDefaults.standard.set(whisperModel.rawValue, forKey: "whisperModel")
        }
    }

    private let apiKeyService = "com.lithuanian-video-transcriber.assemblyai"
    private let apiKeyAccount = "apikey"

    private init() {
        // Load API key from Keychain
        self.assemblyAIAPIKey = SettingsManager.loadAPIKey() ?? ""

        // Load provider preference
        if let providerRaw = UserDefaults.standard.string(forKey: "transcriptionProvider"),
           let provider = TranscriptionProvider(rawValue: providerRaw) {
            self.transcriptionProvider = provider
        } else {
            self.transcriptionProvider = .whisper // Default to free Whisper!
        }

        // Load Whisper model preference
        if let modelRaw = UserDefaults.standard.string(forKey: "whisperModel"),
           let model = WhisperService.WhisperModel(rawValue: modelRaw) {
            self.whisperModel = model
        } else {
            self.whisperModel = .medium // Recommended default
        }
    }

    private func saveAPIKey(_ key: String) {
        let data = key.data(using: .utf8)!

        // Delete old keychain item
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: apiKeyService,
            kSecAttrAccount as String: apiKeyAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new keychain item
        if !key.isEmpty {
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: apiKeyService,
                kSecAttrAccount as String: apiKeyAccount,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
            ]
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    private static func loadAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.lithuanian-video-transcriber.assemblyai",
            kSecAttrAccount as String: "apikey",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            return nil
        }

        return apiKey
    }
}
