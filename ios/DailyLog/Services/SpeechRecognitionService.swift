import AVFoundation
import Foundation
import Speech

@MainActor
final class SpeechRecognitionService: ObservableObject {
    @Published private(set) var transcription: String = ""
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var errorMessage: String?

    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    init(locale: Locale = Locale(identifier: "ja-JP")) {
        recognizer = SFSpeechRecognizer(locale: locale)
    }

    /// 音声認識とマイクの権限を要求する。両方許可されれば true。
    static func requestAuthorization() async -> Bool {
        let speechStatus: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    func startRecording() {
        stopInternal(cancel: true)

        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "音声認識が利用できません"
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            self.request = request

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            transcription = ""
            isRecording = true

            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                Task { @MainActor in
                    if let result {
                        self.transcription = result.bestTranscription.formattedString
                    }
                    if let error {
                        self.errorMessage = error.localizedDescription
                        self.stopInternal(cancel: true)
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            stopInternal(cancel: true)
        }
    }

    /// 認識を確定してエンジン停止。transcription は残す。
    func stopRecording() {
        stopInternal(cancel: false)
    }

    /// 認識を破棄してエンジン停止。transcription もクリア。
    func cancel() {
        stopInternal(cancel: true)
        transcription = ""
    }

    private func stopInternal(cancel: Bool) {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        if cancel {
            task?.cancel()
        } else {
            task?.finish()
        }
        request = nil
        task = nil
        isRecording = false
    }
}
