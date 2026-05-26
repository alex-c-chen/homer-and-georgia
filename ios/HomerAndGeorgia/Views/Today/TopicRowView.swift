import SwiftUI

struct TopicRowView: View {
    let topic: Topic
    let questionCount: Int
    private let tint = Theme.generalTint

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(topic.name)
                    .font(Theme.serif(.body, weight: .bold))
                    .foregroundStyle(Theme.deepSpaceBlue)
                Badge(text: "\(questionCount) questions", color: Theme.deepSpaceBlue.opacity(0.6))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.deepSpaceBlue.opacity(0.25))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            HStack(spacing: 0) {
                UnevenRoundedRectangle(
                    topLeadingRadius: Theme.cardCorner,
                    bottomLeadingRadius: Theme.cardCorner,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .fill(tint)
                .frame(width: 5)
                Color.white
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
        .shadow(color: tint.opacity(0.2), radius: 8, y: 3)
    }
}
