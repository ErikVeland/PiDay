import SwiftUI

// WHY separate file: ConfettiView is a self-contained animation with its own
// timing state. Keeping it out of MainView preserves MainView's coordinator role
// and makes the animation logic independently testable and replaceable.

struct ConfettiView: View {
    /// Increment this value to fire one burst. The view resets automatically.
    let trigger: Int
    let palette: ThemePalette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var startTime: Date? = nil
    private let duration: Double = 0.85
    private let particleCount = 48

    var body: some View {
        // WHY paused: when startTime is nil (no burst in flight) the TimelineView
        // stops ticking entirely — no wasted CPU between bursts.
        // WHY elapsed defaults to duration (not 0): defaulting to 0 when startTime
        // is nil would draw the first frame of the burst (all particles at the
        // origin, full opacity) permanently — the "ghost dot" artifact after the
        // animation completes. Defaulting to duration makes the guard fail so
        // nothing is drawn while the view is idle.
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: startTime == nil)) { context in
            let elapsed = startTime.map { context.date.timeIntervalSince($0) } ?? duration
            Canvas { ctx, size in
                guard elapsed < duration else { return }
                drawParticles(ctx: ctx, size: size, elapsed: elapsed)
            }
            .allowsHitTesting(false)
        }
        // WHY task(id: trigger): fires whenever trigger increments, replacing any
        // in-flight animation. trigger == 0 is the initial state — no burst on launch.
        .task(id: trigger) {
            guard trigger > 0, !reduceMotion else { return }
            startTime = .now
            // Sleep for duration + small buffer to let the last frame render before cleanup.
            try? await Task.sleep(nanoseconds: UInt64((duration + 0.15) * 1_000_000_000))
            startTime = nil
        }
    }

    // MARK: - Drawing

    private func drawParticles(ctx: GraphicsContext, size: CGSize, elapsed: Double) {
        let progress = elapsed / duration
        let origin = CGPoint(x: size.width / 2, y: size.height * 0.45)
        // WHY palette colours: confetti matches the active theme, reinforcing
        // the visual identity rather than jarring with generic rainbow particles.
        let colors: [Color] = [palette.day, palette.month, palette.year, palette.accent]

        for i in 0..<particleCount {
            let seed = Double(i * 7 + trigger * 13)
            let angle = noise(seed) * .pi * 2
            // speed is a fraction of screen width so the burst scales to any device size.
            let speed = 0.28 + noise(seed + 1) * 0.38
            let particleSize = 4 + noise(seed + 2) * 5   // 4–9 pt

            // Smooth launch with gravity pull downward over time.
            let t = min(1.0, progress * 1.6)
            let easedT = t * t * (3 - 2 * t)             // smoothstep easing
            let x = origin.x + cos(angle) * speed * easedT * size.width * 0.55
            let gravityY = progress * progress * size.height * 0.28
            let y = origin.y + sin(angle) * speed * easedT * size.height * 0.38 + gravityY

            // Full opacity until 60% of duration, then linear fade to zero.
            let opacity = progress < 0.6 ? 1.0 : 1.0 - (progress - 0.6) / 0.4

            var gctx = ctx
            gctx.opacity = opacity
            let rect = CGRect(
                x: x - particleSize / 2,
                y: y - particleSize / 2,
                width: particleSize,
                height: particleSize
            )
            // WHY alternate shapes: visual variety makes the burst feel richer
            // without adding rendering cost.
            let shape: Path = i % 3 == 0
                ? Path(ellipseIn: rect)
                : Path(roundedRect: rect, cornerRadius: 2)
            gctx.fill(shape, with: .color(colors[i % colors.count]))
        }
    }

    // WHY deterministic noise (not Swift.random): same trigger value always produces
    // the same burst pattern, preventing jarring visual variation if the view
    // re-renders between frames during the animation.
    private func noise(_ seed: Double) -> Double {
        let v = sin(seed * 12.9898 + 78.233) * 43758.5453
        return v - floor(v)
    }
}
