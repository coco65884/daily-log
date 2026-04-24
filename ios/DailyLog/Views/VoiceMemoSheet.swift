import SwiftUI

struct VoiceMemoSheet: View {
    let activity: Activity

    @Environment(\.dismiss) private var dismiss
    @StateObject private var recognizer = SpeechRecognitionService()
    @State private var authorizationStatus: AuthorizationStatus = .checking

    enum AuthorizationStatus {
        case checking
        case authorized
        case denied
    }

    var body: some View {
        NavigationStack {
            content
                .padding()
                .navigationTitle("音声メモ")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") {
                            recognizer.cancel()
                            dismiss()
                        }
                    }
                }
                .task {
                    if await SpeechRecognitionService.requestAuthorization() {
                        authorizationStatus = .authorized
                        recognizer.startRecording()
                    } else {
                        authorizationStatus = .denied
                    }
                }
                .onDisappear {
                    recognizer.cancel()
                }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var content: some View {
        switch authorizationStatus {
        case .checking:
            ProgressView("権限を確認中…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .denied:
            deniedView
        case .authorized:
            authorizedView
        }
    }

    private var deniedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("マイクまたは音声認識の権限がありません")
                .font(.headline)
            Text("設定アプリから権限を許可してください。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var authorizedView: some View {
        VStack(spacing: 16) {
            statusIndicator

            transcriptionArea

            actionButtons

            if let message = recognizer.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var statusIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(recognizer.isRecording ? Color.red : Color.secondary)
                .frame(width: 10, height: 10)
                .opacity(recognizer.isRecording ? 1 : 0.4)
            Text(recognizer.isRecording ? "録音中" : "停止中")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var transcriptionArea: some View {
        ScrollView {
            Text(displayText)
                .font(.body)
                .foregroundStyle(recognizer.transcription.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .frame(minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var displayText: String {
        recognizer.transcription.isEmpty ? "話しかけてください…" : recognizer.transcription
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            if recognizer.isRecording {
                Button {
                    recognizer.stopRecording()
                } label: {
                    Label("認識を止める", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    recognizer.startRecording()
                } label: {
                    Label("録音", systemImage: "mic.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Button {
                save()
            } label: {
                Label("メモに追加", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(recognizer.transcription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func save() {
        recognizer.stopRecording()
        activity.appendNote(recognizer.transcription)
        try? activity.modelContext?.save()
        dismiss()
    }
}
