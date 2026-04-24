import SwiftUI

struct TemplateButton: View {
    let template: ActivityTemplate
    let action: () -> Void
    var onLongPress: (() -> Void)?

    var body: some View {
        Button(action: action) {
            label
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(onLongPress == nil ? "" : "長押しで子テンプレートを表示")
        .onLongPressGesture(minimumDuration: 0.5) {
            onLongPress?()
        }
    }

    private var label: some View {
        VStack(spacing: 6) {
            iconArea

            Text(template.name)
                .font(.caption)
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(background)
    }

    private var iconArea: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: template.iconName)
                .font(.title2)
                .frame(maxWidth: .infinity)

            if !template.children.isEmpty {
                childrenBadge
            }
        }
    }

    private var childrenBadge: some View {
        Image(systemName: "ellipsis.circle.fill")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.9))
            .background(Circle().fill(.black.opacity(0.25)))
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color(hex: template.colorHex) ?? .accentColor)
    }

    private var accessibilityLabel: String {
        if template.children.isEmpty {
            template.name
        } else {
            "\(template.name)、\(template.children.count) 個の子テンプレート"
        }
    }
}
