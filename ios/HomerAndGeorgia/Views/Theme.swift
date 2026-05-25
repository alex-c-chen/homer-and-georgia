import SwiftUI

enum Theme {
    static let mathTint = Color.indigo        // deep navy/indigo for math
    static let generalTint = Color.orange      // warm amber for general knowledge
    static let success = Color.teal
    static let failure = Color.pink

    static let cardCorner: CGFloat = 28
}

/// LiquidGlass-style card: thin material fill, large corner radius, soft shadow.
/// Falls back gracefully on pre-iOS 26 by using `.thinMaterial`.
struct GlassCard: ViewModifier {
    var tint: Color = .clear

    func body(content: Content) -> some View {
        content
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                            .fill(tint.opacity(tint == .clear ? 0 : 0.10))
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }
}

extension View {
    func glassCard(tint: Color = .clear) -> some View {
        modifier(GlassCard(tint: tint))
    }
}

/// Animated mesh-gradient hero background; degrades to a linear gradient pre-iOS 18.
struct MeshHero: View {
    var colors: [Color] = [.indigo, .purple, .blue, .cyan]

    var body: some View {
        if #available(iOS 18, *) {
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.5, 0.5], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1]
                ],
                colors: meshColors
            )
        } else {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    /// Tile the supplied colors out to the 9 mesh control points.
    private var meshColors: [Color] {
        guard !colors.isEmpty else { return Array(repeating: .indigo, count: 9) }
        return (0..<9).map { colors[$0 % colors.count] }
    }
}

/// Floating glass tab switcher — replaces the stock segmented control.
struct GlassTabBar: View {
    @Binding var selected: Int
    let labels: [String]
    var tint: Color = .primary

    var body: some View {
        GeometryReader { geo in
            let pillWidth = geo.size.width / CGFloat(labels.count)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.ultraThinMaterial)

                // allowsHitTesting(false) so this doesn't block taps on the labels beneath
                Capsule()
                    .fill(tint.opacity(0.18))
                    .overlay(Capsule().strokeBorder(tint.opacity(0.25), lineWidth: 1))
                    .frame(width: pillWidth)
                    .offset(x: CGFloat(selected) * pillWidth)
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selected)
                    .allowsHitTesting(false)

                HStack(spacing: 0) {
                    ForEach(labels.indices, id: \.self) { i in
                        Button { selected = i } label: {
                            Text(labels[i])
                                .font(.subheadline.weight(selected == i ? .semibold : .regular))
                                .foregroundStyle(selected == i ? tint : .secondary)
                                .frame(maxWidth: .infinity)
                                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selected)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(height: 40)
    }
}

/// Small pill badge used for question type / difficulty labels.
struct Badge: View {
    let text: String
    var color: Color = .secondary

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}
