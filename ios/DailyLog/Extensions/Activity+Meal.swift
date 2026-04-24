import Foundation
import SwiftData

extension Activity {
    /// 食事タイプの Activity に対して Meal を確実に存在させる。
    /// 既存の Meal があればそれを返す。
    @discardableResult
    func ensureMeal(in context: ModelContext) -> Meal {
        if let meal {
            return meal
        }
        let new = Meal(activity: self)
        context.insert(new)
        meal = new
        return new
    }
}
