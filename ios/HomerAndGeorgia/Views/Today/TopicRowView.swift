import SwiftUI

struct TopicRowView: View {
    let topic: Topic
    let questionCount: Int
    var tint: Color = Theme.generalTint

    var body: some View {
        HStack(spacing: 16) {
            Text(topic.emoji)
                .font(.system(size: 34))
                .frame(width: 52, height: 52)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(topic.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let description = topic.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Badge(text: "\(questionCount) questions", color: tint)
                    .padding(.top, 2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .glassCard(tint: tint)
    }
}
