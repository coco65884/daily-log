import SwiftUI

struct TemplateRow: View {
    let template: ActivityTemplate

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: template.iconName)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color(hex: template.colorHex) ?? .accentColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(.body)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    if template.isMealType {
                        Label("食事", systemImage: "fork.knife.circle")
                            .labelStyle(.titleAndIcon)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let minutes = template.reminderMinutes {
                        Label("\(minutes)分", systemImage: "bell")
                            .labelStyle(.titleAndIcon)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if !template.children.isEmpty {
                        Label("\(template.children.count)", systemImage: "square.on.square")
                            .labelStyle(.titleAndIcon)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}
