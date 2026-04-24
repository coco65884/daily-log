import SwiftUI

struct TemplateButton: View {
    let template: ActivityTemplate
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: template.iconName)
                    .font(.title2)
                Text(template.name)
                    .font(.caption)
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: template.colorHex) ?? .accentColor)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(template.name)
    }
}
