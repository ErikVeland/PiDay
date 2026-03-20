import SwiftUI

// WHY: First-run onboarding gives new users immediate context before they see the main UI.
// Three swipeable cards introduce the core value props: search, heat map, sharing.
// No environment dependencies — purely presentational, safe for ImageRenderer if needed.

struct OnboardingView: View {
    let onDismiss: () -> Void
    // WHY parameter with default: OnboardingView deliberately has no environment
    // dependencies (it's safe for ImageRenderer). The caller passes the resolved
    // accent colour from PreferencesStore so the onboarding matches the user's
    // active theme. The default falls back to Frost blue if called without a palette.
    var accentColor: Color = Color(red: 0.11, green: 0.44, blue: 0.85)

    @State private var currentPage = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                card1.tag(0)
                card2.tag(1)
                card3.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .ignoresSafeArea()

            // Skip button — top-right, hidden on the final page where Get Started appears.
            if currentPage < 2 {
                VStack {
                    HStack {
                        Spacer()
                        Button("Skip") { onDismiss() }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.top, 56)
                            .padding(.trailing, 24)
                    }
                    Spacer()
                }
                .transition(.opacity)
            }

            if currentPage == 2 {
                Button {
                    onDismiss()
                } label: {
                    Text("Get Started")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(accentColor)
                        )
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentPage)
    }

    // MARK: - Cards

    private var card1: some View {
        onboardingCard(
            symbol: "π",
            symbolIsText: true,
            title: "Your date is hiding in π",
            body: "PiDay searches billions of digits to find exactly where your birthday appears."
        )
    }

    private var card2: some View {
        onboardingCard(
            symbol: "calendar.badge.checkmark",
            symbolIsText: false,
            title: "Heat-map calendar",
            body: "Each day glows hotter based on how early it appears in π. March 14 is Pi Day."
        )
    }

    private var card3: some View {
        onboardingCard(
            symbol: "square.and.arrow.up",
            symbolIsText: false,
            title: "Share the discovery",
            body: "Find your position, then share a card with friends.",
            isLast: true
        )
    }

    // MARK: - Card builder

    private func onboardingCard(symbol: String, symbolIsText: Bool, title: String, body: String, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            Spacer()

            Group {
                if symbolIsText {
                    Text(symbol)
                        .font(.system(size: 80, weight: .black, design: .serif))
                        .italic()
                        .foregroundStyle(accentColor)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 64, weight: .medium))
                        .foregroundStyle(accentColor)
                }
            }
            .padding(.bottom, 32)

            Text(title)
                .font(.system(.title, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 12)

            // Swipe affordance — replaced by Get Started button on the final card.
            if !isLast {
                Label("Swipe to continue", systemImage: "chevron.right")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .labelStyle(.titleAndIcon)
                    .padding(.top, 28)
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
