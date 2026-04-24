# 音声メモ (Speech + AVAudioEngine)

`SFSpeechRecognizer` に `AVAudioEngine` のマイク入力をストリーミングして、進行中の Activity にテキストメモを追記する。

## 1. 権限

2 種類の権限が要る。`Info.plist` と 2 つ:

- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`

iOS 17 からマイク許可は `AVAudioApplication.requestRecordPermission()` に一本化されている (古い `AVAudioSession.requestRecordPermission` は Deprecated)。

```swift
static func requestAuthorization() async -> Bool {
    let speech = await withCheckedContinuation { cont in
        SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
    }
    guard speech == .authorized else { return false }
    return await AVAudioApplication.requestRecordPermission()
}
```

## 2. 認識パイプライン

```swift
final class SpeechRecognitionService: ObservableObject {
    @Published private(set) var transcription = ""
    @Published private(set) var isRecording = false

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func startRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer?.supportsOnDeviceRecognition ?? false
        self.request = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true

        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.transcription = result.bestTranscription.formattedString
                }
                if error != nil { self.stop() }
            }
        }
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()
        request = nil
        task = nil
        isRecording = false
    }
}
```

ポイント:

- `shouldReportPartialResults = true` でストリーミング中の途中結果を表示
- `.measurement` モードは音声認識で推奨 (ノイズ抑制などの前処理が弱く、認識精度が出る)
- `installTap(onBus:bufferSize:format:)` にブロックが渡って、マイクバッファが次々届く → `request.append(buffer)` へ流す
- SFSpeechRecognizer の delegate メソッドは別スレッドから呼ばれることがあるので `Task { @MainActor in ... }` で必ず UI 更新

## 3. UI 側 (本アプリ)

`VoiceMemoSheet` は 3 状態を持つ:

- `.checking`: 権限リクエスト中の `ProgressView`
- `.denied`: 「設定アプリから権限を許可してください」案内
- `.authorized`: 録音中ドット + 認識テキスト + 停止/追加ボタン

確定時は `Activity.appendNote(transcription)` でモデルに追記。

## 4. テスト

SFSpeechRecognizer はマイク + 権限を必要とするため XCTest で完全には再現できない。本アプリでは:

- 純粋ロジック (`Activity.appendNote` の空判定・改行連結) のみ単体テスト
- 録音/認識部分は実機/シミュレータの手動検証

## 注意

- `AVAudioSession.setCategory(.record, ...)` の後に `audioEngine.start()` しないと音が取れない
- 他アプリが `.playback` を握っている状態で `.record` に切り替えると一瞬音が途切れる。`.duckOthers` / `.mixWithOthers` で挙動を選択
- On-device recognition は一部ロケールのみ対応 (`recognizer.supportsOnDeviceRecognition` で判定)
- 長時間録音時はサーバー側 recognition で途切れる場合がある (1 分程度を目安に区切る設計も検討)
