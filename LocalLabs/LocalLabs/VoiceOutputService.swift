//
//  VoiceOutputService.swift
//  LocalLabs
//
//  Text-to-Speech service using AVSpeechSynthesizer
//

import Foundation
import AVFoundation

/// Service for converting text to speech
@MainActor
@Observable
class VoiceOutputService: NSObject {
    /// Singleton instance
    static let shared = VoiceOutputService()

    // MARK: - Properties

    /// Speech synthesizer (must be retained)
    private var synthesizer: AVSpeechSynthesizer?

    /// Currently speaking
    private(set) var isSpeaking: Bool = false

    /// TTS enabled preference
    var isEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "voice_output_enabled")
            if !isEnabled && isSpeaking {
                stopSpeaking()
            }
        }
    }

    /// Selected voice (nil = system default)
    private(set) var selectedVoice: AVSpeechSynthesisVoice?

    /// Speaking rate (0.0 - 1.0, default 0.5)
    var speakingRate: Float = AVSpeechUtteranceDefaultSpeechRate {
        didSet {
            UserDefaults.standard.set(speakingRate, forKey: "voice_speaking_rate")
        }
    }

    /// Pitch multiplier (0.5 - 2.0, default 1.0)
    var pitchMultiplier: Float = 1.0 {
        didSet {
            UserDefaults.standard.set(pitchMultiplier, forKey: "voice_pitch")
        }
    }

    // MARK: - Initialization

    private override init() {
        super.init()

        // Load preferences
        isEnabled = UserDefaults.standard.bool(forKey: "voice_output_enabled")
        speakingRate = UserDefaults.standard.float(forKey: "voice_speaking_rate")
        pitchMultiplier = UserDefaults.standard.float(forKey: "voice_pitch")

        // Set defaults if never set
        if speakingRate == 0 {
            speakingRate = AVSpeechUtteranceDefaultSpeechRate
        }
        if pitchMultiplier == 0 {
            pitchMultiplier = 1.0
        }

        // Initialize synthesizer
        setupSynthesizer()
    }

    private func setupSynthesizer() {
        synthesizer = AVSpeechSynthesizer()
        synthesizer?.delegate = self

        // Configure audio session for playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        } catch {
            print("⚠️ Failed to set audio session category: \(error)")
        }
    }

    // MARK: - Speech Control

    /// Speak the given text
    /// - Parameter text: The text to speak
    /// - Parameter voice: Optional specific voice (nil = use selected/default)
    func speak(_ text: String, voice: AVSpeechSynthesisVoice? = nil) {
        guard isEnabled else {
            print("🔇 TTS disabled, skipping speech")
            return
        }

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("⚠️ Empty text, skipping speech")
            return
        }

        // Stop any current speech
        if isSpeaking {
            stopSpeaking()
        }

        // Create utterance
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice ?? selectedVoice ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = speakingRate
        utterance.pitchMultiplier = pitchMultiplier
        utterance.volume = 1.0

        // Speak
        synthesizer?.speak(utterance)
        isSpeaking = true

        print("🔊 Speaking: \(text.prefix(50))...")
    }

    /// Stop speaking immediately
    func stopSpeaking() {
        synthesizer?.stopSpeaking(at: .immediate)
        isSpeaking = false
        print("🔇 Stopped speaking")
    }

    /// Pause speaking
    func pauseSpeaking() {
        synthesizer?.pauseSpeaking(at: .immediate)
    }

    /// Continue speaking
    func continueSpeaking() {
        synthesizer?.continueSpeaking()
    }

    // MARK: - Voice Selection

    /// Get all available voices for a language
    /// - Parameter languageCode: Language code (e.g., "en-US")
    /// - Returns: Array of available voices
    static func availableVoices(for languageCode: String = "en-US") -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices().filter { voice in
            voice.language.hasPrefix(languageCode)
        }
    }

    /// Set the voice to use
    /// - Parameter voice: The voice to use (nil = system default)
    func setVoice(_ voice: AVSpeechSynthesisVoice?) {
        selectedVoice = voice
        if let voice = voice {
            UserDefaults.standard.set(voice.identifier, forKey: "selected_voice_id")
        } else {
            UserDefaults.standard.removeObject(forKey: "selected_voice_id")
        }
    }

    /// Load saved voice preference
    func loadSavedVoice() {
        if let voiceID = UserDefaults.standard.string(forKey: "selected_voice_id") {
            selectedVoice = AVSpeechSynthesisVoice(identifier: voiceID)
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceOutputService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = true
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
            print("✅ Finished speaking")
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
            print("🚫 Speech cancelled")
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        print("⏸️ Speech paused")
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        print("▶️ Speech continued")
    }
}
