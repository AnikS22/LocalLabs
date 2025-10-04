//
//  VoiceInputService.swift
//  LocalLabs
//
//  Speech-to-Text service using Apple's Speech framework
//

import Foundation
import Speech
import AVFoundation

/// Service for converting speech to text
@MainActor
@Observable
class VoiceInputService: NSObject {
    /// Singleton instance
    static let shared = VoiceInputService()

    // MARK: - Properties

    /// Speech recognizer for transcription
    private var speechRecognizer: SFSpeechRecognizer?

    /// Recognition request
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    /// Recognition task
    private var recognitionTask: SFSpeechRecognitionTask?

    /// Audio engine for capturing microphone input
    private let audioEngine = AVAudioEngine()

    /// Current transcribed text
    private(set) var transcribedText: String = ""

    /// Whether currently recording
    private(set) var isRecording: Bool = false

    /// Permission status
    private(set) var permissionStatus: VoicePermissionStatus = .notDetermined

    // MARK: - Initialization

    private override init() {
        super.init()
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        checkPermissions()
    }

    // MARK: - Permission Management

    /// Check current permission status
    private func checkPermissions() {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let micStatus = AVAudioSession.sharedInstance().recordPermission

        if speechStatus == .authorized && micStatus == .granted {
            permissionStatus = .authorized
        } else if speechStatus == .denied || micStatus == .denied {
            permissionStatus = .denied
        } else {
            permissionStatus = .notDetermined
        }
    }

    /// Request microphone and speech recognition permissions
    func requestPermissions() async -> Bool {
        // Request microphone permission
        let micGranted = await requestMicrophonePermission()
        guard micGranted else {
            permissionStatus = .denied
            return false
        }

        // Request speech recognition permission
        let speechGranted = await requestSpeechRecognitionPermission()
        guard speechGranted else {
            permissionStatus = .denied
            return false
        }

        permissionStatus = .authorized
        return true
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func requestSpeechRecognitionPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    // MARK: - Recording Control

    /// Start recording and transcribing speech
    func startRecording() async throws {
        // Cancel any ongoing recognition
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceError.recognitionRequestFailed
        }

        recognitionRequest.shouldReportPartialResults = true

        // Get input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        // Prepare and start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                Task { @MainActor in
                    self.transcribedText = result.bestTranscription.formattedString
                }
            }

            if error != nil || (result?.isFinal ?? false) {
                Task { @MainActor in
                    self.stopRecording()
                }
            }
        }

        isRecording = true
        print("🎤 Started recording")
    }

    /// Stop recording and return final transcription
    func stopRecording() -> String {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        isRecording = false

        let finalText = transcribedText
        transcribedText = "" // Clear for next recording

        print("🎤 Stopped recording. Transcribed: \(finalText)")
        return finalText
    }

    /// Cancel recording without returning text
    func cancelRecording() {
        _ = stopRecording()
    }
}

// MARK: - Supporting Types

/// Permission status for voice input
enum VoicePermissionStatus {
    case notDetermined
    case authorized
    case denied
    case restricted

    var isAuthorized: Bool {
        self == .authorized
    }
}

/// Voice-related errors
enum VoiceError: LocalizedError {
    case permissionDenied
    case recognitionRequestFailed
    case audioEngineError
    case speechRecognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone or speech recognition permission denied"
        case .recognitionRequestFailed:
            return "Failed to create speech recognition request"
        case .audioEngineError:
            return "Audio engine error"
        case .speechRecognizerUnavailable:
            return "Speech recognizer not available for this language"
        }
    }
}
