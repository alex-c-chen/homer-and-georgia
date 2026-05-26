import SwiftUI
import UIKit

// MARK: - Hex colour helper

extension Color {
    init(hex: UInt32) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255
        )
    }
}

// MARK: - Theme

enum Theme {
    // MARK: Palette
    static let deepSpaceBlue = Color(hex: 0x1C3144)
    static let burntOrange   = Color(hex: 0xBF5700)
    static let brickEmber    = Color(hex: 0xD00000)
    static let amberFlame    = Color(hex: 0xFFBA08)
    static let parchment     = Color(hex: 0xF5EDCC)  // warm eggshell / soft goldenrod
    static let steelBlue     = Color(hex: 0x3F88C5)

    // MARK: Semantic
    static let mathTint    = amberFlame
    static let generalTint = brickEmber
    static let success     = Color.teal
    static let failure     = brickEmber

    // MARK: Typography

    /// Point size at the default (Large) Dynamic Type setting, per text style.
    /// Needed because custom fonts don't auto-size the way `.system(_:)` does;
    /// `relativeTo:` then re-enables Dynamic Type scaling around this base size.
    private static func pointSize(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle:  34
        case .title:       28
        case .title2:      22
        case .title3:      20
        case .headline:    17
        case .body:        17
        case .callout:     16
        case .subheadline: 15
        case .footnote:    13
        case .caption:     12
        case .caption2:    11
        default:           17
        }
    }

    /// Elegant serif (Baskerville) for reading content; scales with Dynamic Type.
    static func serif(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .custom("Baskerville", size: pointSize(style), relativeTo: style).weight(weight)
    }

    /// System sans-serif for large display headings.
    static func sans(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .default).weight(weight)
    }

    // MARK: Corner radii
    static let cardCorner:  CGFloat = 28
    static let inputCorner: CGFloat = 18
    static let iconCorner:  CGFloat = 16
    static let bubbleCorner: CGFloat = 20
    static let ctaCorner:   CGFloat = 22
}

// MARK: - GlassCard

/// Thin-material card with large corner radius and soft shadow.
struct GlassCard: ViewModifier {
    var tint: Color = .clear

    func body(content: Content) -> some View {
        content
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                    .fill(Color(.systemGray6))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                            .fill(tint.opacity(tint == .clear ? 0 : 0.12))
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

    /// Thin-material background on < iOS 26; native glass on iOS 26+.
    @ViewBuilder
    func glassBackground() -> some View {
        if #available(iOS 26, *) {
            glassEffect()
        } else {
            background(.thinMaterial)
        }
    }

    /// Shaped thin-material background on < iOS 26; native glass on iOS 26+.
    @ViewBuilder
    func glassBackground<S: InsettableShape>(in shape: S) -> some View {
        if #available(iOS 26, *) {
            glassEffect(in: shape)
        } else {
            background(.thinMaterial, in: shape)
        }
    }
}

// MARK: - MeshHero

/// Animated mesh-gradient hero background; degrades to a linear gradient pre-iOS 18.
struct MeshHero: View {
    var colors: [Color] = [Theme.steelBlue, Theme.deepSpaceBlue, Theme.amberFlame, Theme.parchment]

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

    private var meshColors: [Color] {
        guard !colors.isEmpty else { return Array(repeating: Theme.steelBlue, count: 9) }
        return (0..<9).map { colors[$0 % colors.count] }
    }
}

// MARK: - GlassTabBar

/// Floating glass tab switcher.
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
                                .font(Theme.serif(.subheadline, weight: selected == i ? .semibold : .regular))
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

// MARK: - ZoomTransitionModifier

private struct ZoomTransitionModifier<ID: Hashable>: ViewModifier {
    let sourceID: ID
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *), let ns = namespace {
            content.navigationTransition(.zoom(sourceID: sourceID, in: ns))
        } else {
            content
        }
        #else
        content
        #endif
    }
}

extension View {
    func zoomNavigationTransition<ID: Hashable>(sourceID: ID, namespace: Namespace.ID?) -> some View {
        modifier(ZoomTransitionModifier(sourceID: sourceID, namespace: namespace))
    }
}

// MARK: - Forced light interface style

/// Forces a SwiftUI subtree to render in light mode even inside a globally dark
/// app. `preferredColorScheme` is window-scoped and cannot override a global
/// `.dark`; setting `overrideUserInterfaceStyle` on the hosting view controller
/// is the supported per-screen override and scopes cleanly to the pushed screen.
private struct LightInterfaceStyle: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { StyleController() }

    func updateUIViewController(_ vc: UIViewController, context: Context) {
        vc.parent?.overrideUserInterfaceStyle = .light
    }

    final class StyleController: UIViewController {
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            parent?.overrideUserInterfaceStyle = .light
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            parent?.overrideUserInterfaceStyle = .light
        }
    }
}

extension View {
    /// Render this subtree in light mode regardless of the global colour scheme.
    func lightInterfaceStyle() -> some View {
        background(LightInterfaceStyle())
    }
}

// MARK: - Badge

/// Small pill badge used for question type / difficulty labels.
struct Badge: View {
    let text: String
    var color: Color = .secondary

    var body: some View {
        Text(text)
            .font(Theme.serif(.caption2, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}
