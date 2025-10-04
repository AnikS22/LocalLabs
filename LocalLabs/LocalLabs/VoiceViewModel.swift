//
//  VoiceViewModel.swift
//  LocalLabs
//
//  ViewModel for managing voice interaction state
//

import Foundation

/// ViewModel for voice features in ChatView
@MainActor
@Observable
class VoiceViewModel {
    // MARK: - Services

    private let voiceInput = VoiceInputService.shared
    private let voiceOutput = VoiceOutputService.shared

    // MARK: - State

    /// Permission state
    var permissionStatus: VoicePermissionStatus {
        voiceInput.permissionStatus
    }

    /// Currently recording
    var isRecording: Bool {
        voiceInput.isRecording
    }

    /// TTS enabled
    var isTTSEnabled: Bool {
        get { voiceOutput.isEnabled }
        set { voiceOutput.isEnabled = newValue }
    }

    /// Currently speaking
    var isSpeaking: Bool {
        voiceOutput.isSpeaking
    }

    /// Transcribed text from voice input
    var transcribedText: String {
        voiceInput.transcribedText
    }

    /// Show permission alert
    var showPermissionAlert: Bool = false

    /// Error message
    var errorMessage: String?

    /// Show error alert
    var showError: Bool = false

    // MARK: - Voice Input

    /// Request permissions for voice input
    func requestPermissions() async {
        let granted = await voiceInput.requestPermissions()
        if !granted {
            showPermissionAlert = true
        }
    }

    /// Start voice recording
    func startRecording() async {
        // Check permissions
        if !permissionStatus.isAuthorized {
            await requestPermissions()
            guard permissionStatus.isAuthorized else { return }
        }

        // Stop any current TTS
        if isSpeaking {
            voiceOutput.stopSpeaking()
        }

        // Start recording
        do {
            try await voiceInput.startRecording()
        } catch {
            handleError(error)
        }
    }

    /// Stop voice recording and return transcription
    func stopRecording() -> String {
        return voiceInput.stopRecording()
    }

    /// Cancel recording without returning text
    func cancelRecording() {
        voiceInput.cancelRecording()
    }

    // MARK: - Voice Output

    /// Speak the given text (if TTS enabled)
    func speak(_ text: String) {
        voiceOutput.speak(text)
    }

    /// Stop speaking
    func stopSpeaking() {
        voiceOutput.stopSpeaking()
    }

    /// Toggle TTS on/off
    func toggleTTS() {
        isTTSEnabled.toggle()
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
        print("❌ Voice error: \(error.localizedDescription)")
    }
}
