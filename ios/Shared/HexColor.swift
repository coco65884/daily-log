import Foundation

/// 6 桁 hex 文字列ベースの色操作ユーティリティ。
///
/// SwiftUI の `Color` には HSB 取り出し API がない (UIColor 経由で取れるが
/// `Shared/` は AppKit/UIKit 非依存にしておきたい)。ここでは RGB 同士の線形
/// 補間で「白 / 黒に寄せたシェード」を作る。
enum HexColor {
    struct RGB: Equatable {
        let red: Double
        let green: Double
        let blue: Double
    }

    /// `amount` (>0 で白寄り、<0 で黒寄り、[-1, 1]) で色をブレンドした hex を返す。
    /// パースに失敗したら入力をそのまま返す。
    static func mixed(hex: String, amount: Double) -> String {
        guard let rgb = parse(hex: hex) else { return hex }
        let clamped = max(-1, min(1, amount))
        let target: Double = clamped >= 0 ? 1.0 : 0.0
        let weight = abs(clamped)
        let red = rgb.red + (target - rgb.red) * weight
        let green = rgb.green + (target - rgb.green) * weight
        let blue = rgb.blue + (target - rgb.blue) * weight
        return format(red: red, green: green, blue: blue)
    }

    /// 親の色から、子の sortOrder 位置 (0始まり) で連続的にずらしたシェード hex を返す。
    /// 偶数 index → 明、奇数 index → 暗を交互に重ねる。
    static func shaded(parentHex: String, childIndex: Int) -> String {
        let step = 0.18
        let magnitude = Double((childIndex / 2) + 1) * step
        let lighter = childIndex % 2 == 0
        let amount = lighter ? magnitude : -magnitude
        return mixed(hex: parentHex, amount: amount)
    }

    static func parse(hex: String) -> RGB? {
        var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") {
            trimmed.removeFirst()
        }
        guard trimmed.count == 6, let value = UInt32(trimmed, radix: 16) else {
            return nil
        }
        return RGB(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    private static func format(red: Double, green: Double, blue: Double) -> String {
        let rInt = Int((red * 255).rounded())
        let gInt = Int((green * 255).rounded())
        let bInt = Int((blue * 255).rounded())
        return String(format: "#%02X%02X%02X", rInt, gInt, bInt)
    }
}
