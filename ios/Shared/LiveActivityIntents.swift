import AppIntents
import Foundation
#if HOST_APP
    import SwiftData
#endif

/// ロック画面 / Dynamic Island の停止ボタンから呼ばれる。
///
/// `LiveActivityIntent` は host app プロセスで実行されるため、本体アプリと
/// 同じ SwiftData ストア / `ActivityService` を経由してデータ整合性を保てる。
/// Shared/ に置いてあるが perform 本体は host 限定 (`#if HOST_APP`)。
struct StopCurrentActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "現在のアクションを停止"
    static var description = IntentDescription("進行中のアクションをロック画面から停止します。")

    func perform() async throws -> some IntentResult {
        #if HOST_APP
            try await MainActor.run {
                let container = try AppModelContainer.makeContainer()
                let context = ModelContext(container)
                let service = ActivityService(context: context)
                try service.stopCurrent()
            }
        #endif
        return .result()
    }
}

/// 候補アクションをタップしたときに呼ばれる。指定 ID のテンプレで開始する。
struct StartTemplateIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "アクションを開始"
    static var description = IntentDescription("指定されたアクションを開始します。")

    @Parameter(title: "Template ID")
    var templateIDString: String

    init() {
        templateIDString = ""
    }

    init(templateID: UUID) {
        templateIDString = templateID.uuidString
    }

    func perform() async throws -> some IntentResult {
        #if HOST_APP
            guard let templateID = UUID(uuidString: templateIDString) else {
                return .result()
            }
            try await MainActor.run {
                let container = try AppModelContainer.makeContainer()
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<ActivityTemplate>(
                    predicate: #Predicate { $0.id == templateID }
                )
                guard let template = try context.fetch(descriptor).first else { return }
                let service = ActivityService(context: context)
                try service.start(template: template)
            }
        #endif
        return .result()
    }
}
