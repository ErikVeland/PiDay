import SwiftUI

// WHY: Reusable modifiers extracted from views so they can be applied anywhere.
// Keeping them in Design/ makes them easy to find and update across features.

// MARK: - NativeGlassButtonModifier

struct NativeGlassButtonModifier: ViewModifier {
    @Environment(PreferencesStore.self) private var preferences

    func body(content: Content) -> some View {
        let palette = preferences.resolvedPalette
        if #available(iOS 26, *) {
            content
                .buttonStyle(.plain)
                .contentShape(Circle())
                .background {
                    Circle()
                        .fill(.clear)
                        // WHY background glass instead of applying glassEffect to
                        // the button view itself: this preserves the native liquid
                        // glass look while keeping the tappable control layer as the
                        // real hit-test target on iOS 26.x.
                        .glassEffect(.regular, in: Circle())
                        .allowsHitTesting(false)
                }
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.14), lineWidth: 0.75)
                        .allowsHitTesting(false)
                )
                .shadow(color: palette.ink.opacity(0.10), radius: 14, y: 8)
        } else {
            content
                .buttonStyle(.plain)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        // WHY Color.primary.opacity: adapts to both light and dark
                        // themes instead of hardcoded white, which disappears on
                        // dark custom themes (Slate, Aurora, Coppice).
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.white.opacity(0.18), radius: 12, y: -1)
                .shadow(color: palette.ink.opacity(0.12), radius: 18, y: 8)
        }
    }
}

// MARK: - GlassCardModifier

// WHY GlassCardModifier: iOS 26 expects floating card surfaces to use Liquid Glass.
// Centralising the availability check avoids repeating it in every card-shaped view.
// On iOS < 26 the modifier falls back to theme-aware surface + border colours,
// which also fixes the longstanding bug where hardcoded Color.white looked broken
// on dark themes (Slate, Coppice, Aurora).
struct GlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat
    let palette: ThemePalette

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            // WHY no background fill on iOS 26: Liquid Glass already provides its own
            // translucent surface material. Adding an opaque fill behind it stacks two
            // surfaces and makes the card look muddy/non-glassy. The border overlay is
            // kept because it adds definition at card edges that glass alone doesn't provide.
            content
                .glassEffect(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(palette.paneBorder(for: colorScheme), lineWidth: 1)
                )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(palette.paneSurfaceFill(for: colorScheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(palette.paneBorder(for: colorScheme), lineWidth: 1)
                        )
                )
        }
    }
}

// MARK: - CompactSectionCardModifier

struct CompactSectionCardModifier: ViewModifier {
    @Environment(PreferencesStore.self) private var preferences

    func body(content: Content) -> some View {
        let palette = preferences.resolvedPalette
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            // WHY GlassCardModifier: upgrades to Liquid Glass on iOS 26+
            // while staying theme-aware on older OS versions.
            .modifier(GlassCardModifier(cornerRadius: 18, palette: palette))
    }
}

// MARK: - Convenience extensions

extension View {
    func compactSectionCard() -> some View {
        modifier(CompactSectionCardModifier())
    }

    func glassCard(cornerRadius: CGFloat = 20, palette: ThemePalette) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, palette: palette))
    }
}

#if compiler(<6.3)
extension View {
    @ViewBuilder
    func glassEffect<S: Shape>(_ style: Material, in shape: S) -> some View {
        self
    }
    
    @ViewBuilder
    func glassEffect<S: Shape>(in shape: S) -> some View {
        self
    }
}
#endif
