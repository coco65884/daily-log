import SwiftUI
import UIKit

/// `UICalendarView` の SwiftUI ラッパー。
///
/// - `datesWithActivity` に含まれる日にデコレーションを表示する
/// - 日付を選択すると `selectedDate` が更新される
struct ActivityCalendar: UIViewRepresentable {
    @Binding var selectedDate: Date?
    let datesWithActivity: Set<DateComponents>

    func makeUIView(context: Context) -> UICalendarView {
        let view = UICalendarView()
        view.calendar = Calendar(identifier: .gregorian)
        view.locale = Locale.current
        view.delegate = context.coordinator
        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        view.selectionBehavior = selection
        return view
    }

    func updateUIView(_ uiView: UICalendarView, context: Context) {
        let previousDates = context.coordinator.datesWithActivity
        context.coordinator.datesWithActivity = datesWithActivity
        let changed = previousDates.symmetricDifference(datesWithActivity)
        if !changed.isEmpty {
            uiView.reloadDecorations(forDateComponents: Array(changed), animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            datesWithActivity: datesWithActivity,
            onSelect: { selectedDate = $0 }
        )
    }

    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var datesWithActivity: Set<DateComponents>
        let onSelect: (Date?) -> Void

        init(datesWithActivity: Set<DateComponents>, onSelect: @escaping (Date?) -> Void) {
            self.datesWithActivity = datesWithActivity
            self.onSelect = onSelect
        }

        func calendarView(
            _ calendarView: UICalendarView,
            decorationFor dateComponents: DateComponents
        ) -> UICalendarView.Decoration? {
            let ymd = DateComponents(
                year: dateComponents.year,
                month: dateComponents.month,
                day: dateComponents.day
            )
            guard datesWithActivity.contains(ymd) else { return nil }
            return .default(color: .systemBlue, size: .medium)
        }

        func dateSelection(
            _ selection: UICalendarSelectionSingleDate,
            didSelectDate dateComponents: DateComponents?
        ) {
            guard let dateComponents else {
                onSelect(nil)
                return
            }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .current
            onSelect(calendar.date(from: dateComponents))
        }
    }
}
