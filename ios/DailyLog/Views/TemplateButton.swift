import SwiftUI

struct TemplateButton: View {
    let template: ActivityTemplate
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
        }
        .buttonStyle(.plain)
        .accessibilityLabel(template.name)
    }

    private var label: some View {
        VStack(spacing: 6) {
            Image(systemName: template.iconName)
                .font(.title2)
                .frame(maxWidth: .infinity)

            Text(template.name)
                .font(.caption)
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(background)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color(hex: template.colorHex) ?? .accentColor)
    }
}
