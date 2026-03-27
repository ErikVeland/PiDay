import SwiftUI
import StoreKit
import UIKit

// WHY: MainView is the root coordinator. Its job is:
//   1. Lay out the three layers (canvas, wordmark, controls)
//   2. Own the sheet presentation state
//   3. Own the reveal animation state
//   4. Handle swipe gestures
//
// It deliberately has no business logic — all state mutations go through AppViewModel.

struct MainView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(PreferencesStore.self) private var preferences
    @Environment(\.requestReview) private var requestReview
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var revealSequence = false
    @State private var showCalendar = false
    @State private var showDetails = false
    @State private var hapticTrigger = false
    // WHY separate per-button triggers: each chevron button should only bounce
    // its own icon, not both simultaneously.
    @State private var prevDayBounce = false
    @State private var nextDayBounce = false
    @State private var calendarBounce = false
    @State private var detailsBounce = false
    @State private var statsBounce = false
    @State private var confettiTrigger = 0
    @State private var showFreeSearch = false
    @State private var showStats = false

    var body: some View {
        let palette = preferences.resolvedPalette

        ZStack {
            palette.background.ignoresSafeArea()

            PiCanvasView(revealSequence: revealSequence)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .gesture(dateSwipeGesture)

            VStack(spacing: 0) {
                topWordmark
                    .padding(.top, 22)
                Spacer()
            }

            VStack(spacing: 0) {
                Spacer()
                ResultStripView(onFreeSearch: { showFreeSearch = true })
                    .padding(.bottom, 6)
                bottomControls
                    .padding(.bottom, 18)
            }

            // WHY overlay: confetti sits above the canvas but passes touches through
            // (allowsHitTesting(false) is set inside ConfettiView itself).
            ConfettiView(trigger: confettiTrigger, palette: palette)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)

            if viewModel.isLoading {
                loadingOverlay(palette: palette)
            }
        }
        .sheet(isPresented: $showCalendar) {
            // WHY explicit .environment: @Observable objects don't always propagate
            // through sheet closures automatically on all OS versions (known SwiftUI bug
            // on macOS/Mac Catalyst and iOS 26 betas). Re-injecting the same references
            // ensures the child view hierarchy can read them via @Environment.
            CalendarSheetView(isPresented: $showCalendar)
                .environment(viewModel)
                .environment(preferences)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDetails) {
            DetailSheetView(isPresented: $showDetails)
                .environment(viewModel)
                .environment(preferences)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFreeSearch) {
            FreeSearchView()
                .environment(viewModel)
                .environment(preferences)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showStats) {
            StatsView(isPresented: $showStats)
                .environment(viewModel)
                .environment(preferences)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        // Restart the reveal animation whenever the target query changes.
        // WHY reduceMotion check: users who opt out of motion get an instant
        // reveal instead of the spring animation — same information, no motion.
        .task(id: viewModel.exactQuery) {
            revealSequence = false
            if reduceMotion {
                revealSequence = true
            } else {
                try? await Task.sleep(nanoseconds: 120_000_000)
                withAnimation(.spring(response: 0.48, dampingFraction: 0.72)) {
                    revealSequence = true
                }
            }
        }
        // Keep PreferencesStore's systemColorScheme in sync with the actual environment
        // value so resolvedPalette can pick the correct dark/light variant.
        .onChange(of: colorScheme, initial: true) { _, cs in
            preferences.systemColorScheme = cs
        }
        .sensoryFeedback(.selection, trigger: hapticTrigger)
        // Trigger the StoreKit rating dialog when the ViewModel signals readiness.
        // WHY here (not in the ViewModel): @Environment(\.requestReview) only exists in Views.
        .onChange(of: viewModel.shouldPromptForRating) { _, newValue in
            guard newValue else { return }
            requestReview()
            viewModel.acknowledgeRatingPrompt()
        }
        // WHY accessibility announcements on loading changes: VoiceOver users have no
        // visual cue that data is being fetched. Announcing start and completion lets
        // them know when it's safe to interact with the canvas and detail sheet.
        // WHY UIAccessibility.post: guaranteed to work on all iOS 17+ targets without
        // importing the Accessibility framework separately.
        .onChange(of: viewModel.isLoading) { _, newValue in
            UIAccessibility.post(
                notification: .announcement,
                argument: newValue ? "Loading pi data" : "Pi data ready"
            )
        }
        // Fire confetti only when the user explicitly looked up a birthday via the
        // contact picker and a match was found. The ViewModel increments
        // birthdayConfettiVersion from inside refreshSelection so the signal is
        // guaranteed to arrive after the result is ready.
        .onChange(of: viewModel.birthdayConfettiVersion) { _, _ in
            confettiTrigger += 1
        }
    }

    // MARK: - Bottom controls

    private var bottomControls: some View {
        HStack(spacing: 12) {
            floatingButton(
                systemName: "calendar",
                accessibilityLabel: "Open calendar",
                size: 56,
                bounce: calendarBounce
            ) {
                showCalendar = true
                calendarBounce.toggle()
                hapticTrigger.toggle()
            }

            // Previous day — has its own bounce trigger so only the left chevron animates.
            Button {
                viewModel.showPreviousDay()
                prevDayBounce.toggle()
                hapticTrigger.toggle()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.bold))
                    // WHY reduceMotion guard: .bounce adds motion; skip it entirely
                    // when the user has requested reduced motion in Settings.
                    .symbolEffect(.bounce, options: .nonRepeating, value: reduceMotion ? false : prevDayBounce)
                    .frame(width: 56, height: 56)
            }
            .modifier(NativeGlassButtonModifier())
            .foregroundStyle(preferences.resolvedPalette.ink)
            .accessibilityLabel("Previous day")

            floatingButton(
                systemName: "info.circle",
                accessibilityLabel: "Date details",
                size: 56,
                bounce: detailsBounce
            ) {
                showDetails = true
                detailsBounce.toggle()
                hapticTrigger.toggle()
            }

            // Next day — has its own bounce trigger so only the right chevron animates.
            Button {
                viewModel.showNextDay()
                nextDayBounce.toggle()
                hapticTrigger.toggle()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.bold))
                    .symbolEffect(.bounce, options: .nonRepeating, value: reduceMotion ? false : nextDayBounce)
                    .frame(width: 56, height: 56)
            }
            .modifier(NativeGlassButtonModifier())
            .foregroundStyle(preferences.resolvedPalette.ink)
            .accessibilityLabel("Next day")

            floatingShareButton(size: 56)
        }
        .frame(maxWidth: 480)
        .padding(.horizontal, 16)
    }

    private func floatingButton(
        systemName: String,
        accessibilityLabel: String,
        size: CGFloat,
        bounce: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.headline.weight(.bold))
                .symbolEffect(.bounce, options: .nonRepeating, value: reduceMotion ? false : bounce)
                .frame(width: size, height: size)
        }
        .modifier(NativeGlassButtonModifier())
        .foregroundStyle(preferences.resolvedPalette.ink)
        .accessibilityLabel(accessibilityLabel)
    }

    private func floatingShareButton(size: CGFloat) -> some View {
        // ShareLink(item:) with a Transferable renders a PNG share card via ImageRenderer.
        // The plain-text fallback lives in detailShareText (still used in DetailSheetView copy).
        ShareLink(item: viewModel.shareableCard(palette: preferences.resolvedPalette), preview: SharePreview("PiDay", image: Image(systemName: "chart.bar.doc.horizontal"))) {
            Image(systemName: "square.and.arrow.up")
                .font(.headline.weight(.bold))
                .frame(width: size, height: size)
        }
        .modifier(NativeGlassButtonModifier())
        .foregroundStyle(preferences.resolvedPalette.ink)
        .accessibilityLabel("Share")
        // WHY disabled during loading: sharing while a lookup is in flight would
        // produce a "not found" share card even if the date actually exists in pi.
        .disabled(viewModel.isLoading || viewModel.errorMessage != nil)
    }

    // MARK: - Wordmark

    private var topWordmark: some View {
        let palette = preferences.resolvedPalette

        return HStack(alignment: .firstTextBaseline, spacing: -4) {
                Text("∏")
                    .font(.system(size: 24, weight: .black, design: .serif))
                    .italic()
                Text("day")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .tracking(0.8)
            }
            .foregroundStyle((palette.ink.opacity(0.9) as Color))
            // WHY conditional halo: on dark themes the ink is light, so the outer
            // halo needs to be dark (a shadow that grounds the letterform). On light
            // themes the ink is dark, so the halo should be white (a lift highlight).
            .shadow(
                color: (preferences.effectiveColorScheme == .dark
                    ? Color.black.opacity(0.60)
                    : Color.white.opacity(0.86)) as Color,
                radius: 6, y: preferences.effectiveColorScheme == .dark ? 1 : -1
            )
            .shadow(color: (palette.accent.opacity(0.2) as Color), radius: 18, y: 2)
            .overlay(
                HStack(alignment: .firstTextBaseline, spacing: -4) {
                    Text("∏")
                        .font(.system(size: 24, weight: .black, design: .serif))
                        .italic()
                    Text("day")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .tracking(0.8)
                }
                .foregroundStyle((Color.white.opacity(0.20) as Color))
                .blur(radius: 0.4)
            )
            .fixedSize()
            .opacity(0.94)
            .contentShape(Rectangle())
            .onTapGesture {
                showStats = true
                statsBounce.toggle()
                hapticTrigger.toggle()
            }
            .accessibilityLabel("Show Pi Stats")
            .accessibilityAddTraits(.isButton)
    }

    // MARK: - Loading overlay

    private func loadingOverlay(palette: ThemePalette) -> some View {
        ZStack {
            palette.background
                .ignoresSafeArea()
                .opacity(0.85)
            // WHY label: on older devices, decoding the 12.6 MB JSON can take
            // 1–3 seconds. A spinner with no text gives users no cue about what
            // is happening. "Loading π…" names the work concisely.
            VStack(spacing: 12) {
                ProgressView()
                    .tint(palette.mutedInk)
                Text("Loading π…")
                    .font(.caption)
                    .foregroundStyle(palette.mutedInk)
            }
        }
        .transition(.opacity)
        .allowsHitTesting(true)
    }

    // MARK: - Gesture

    private var dateSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 22, coordinateSpace: .local)
            .onEnded { value in
                let h = value.translation.width
                let v = value.translation.height
                // WHY vertical branch first: swipe-up opens the detail sheet.
                // Horizontal swipes navigate days (existing behaviour).
                // We only treat it as vertical when it's clearly more vertical than
                // horizontal, so diagonal drags still navigate days as before.
                if abs(v) > abs(h), v < -50 {
                    showDetails = true
                    hapticTrigger.toggle()
                    return
                }
                if abs(v) > abs(h), v > 50 {
                    showStats = true
                    hapticTrigger.toggle()
                    return
                }
                guard abs(h) > abs(v), abs(h) > 36 else { return }
                if h < 0 {
                    viewModel.showNextDay()
                    nextDayBounce.toggle()
                } else {
                    viewModel.showPreviousDay()
                    prevDayBounce.toggle()
                }
                hapticTrigger.toggle()
            }
    }
}
