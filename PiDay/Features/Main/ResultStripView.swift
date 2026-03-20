import SwiftUI
import UIKit

// WHY a separate file: ResultStripView is an always-visible UI component that
// bridges the canvas and the bottom controls. Keeping it in its own file makes
// it easy to iterate on the strip's layout and context-menu actions without
// scrolling past the full MainView implementation. It also gives the strip a
// clear seam for future extraction into a standalone package or preview target.

struct ResultStripView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(PreferencesStore.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    let onFreeSearch: () -> Void

    var body: some View {
        let palette = preferences.resolvedPalette
        HStack(spacing: 0) {
            dateLabel(palette: palette)
            Spacer(minLength: 12)
            resultLabel(palette: palette)
        }
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .contextMenu { contextMenuItems(palette: palette) }
    }

    // Left side: formatted selected date — gives the user instant confirmation
    // of which date the strip is describing without opening the detail sheet.
    private func dateLabel(palette: ThemePalette) -> some View {
        Text(shortDate(viewModel.selectedDate))
            .foregroundStyle(palette.ink.opacity(0.85))
            .lineLimit(1)
    }

    // Right side: loading / error / found / not-found / out-of-range.
    // WHY @ViewBuilder: the five states return structurally different view types.
    // @ViewBuilder lets Swift unify them into an opaque `some View` at compile time
    // without an AnyView type-erasure penalty.
    @ViewBuilder
    private func resultLabel(palette: ThemePalette) -> some View {
        if viewModel.isLoading {
            ProgressView()
                .tint(palette.mutedInk)
                .scaleEffect(0.75)
        } else if viewModel.errorMessage != nil {
            Label("Error", systemImage: "exclamationmark.wifi")
                .foregroundStyle(PiPalette.error)
                .lineLimit(1)
        } else if let match = viewModel.bestMatch {
            HStack(spacing: 6) {
                HStack(spacing: 0) {
                    Text("digit ")
                    AnimatedCounterView(target: viewModel.displayedPosition(for: match.storedPosition))
                }
                .foregroundStyle(palette.ink.opacity(0.85))

                // WHY conditional indicator: at "faint" level (positions past ~10 million)
                // the heat bars are barely visible at strip size — one small lit bar against
                // a light background reads as blank space. Only show the separator and
                // indicator for cool/warm/hot where the visual is meaningful.
                if viewModel.resultHeatLevel != .faint {
                    Text("·")
                        .foregroundStyle(palette.mutedInk)

                    HeatIndicatorView(
                        heatLevel: viewModel.resultHeatLevel,
                        color: heatColor(palette: palette)
                    )
                }
            }
            .lineLimit(1)
        } else {
            // WHY single branch: by the time we reach here, isLoading is already false
            // (the ProgressView branch above catches loading). Both in-range "not found"
            // and out-of-range "no live match" mean the same thing to the user: no result.
            // The Detail sheet provides the nuanced explanation if they want it.
            Text("Not found in π")
                .foregroundStyle(palette.mutedInk)
                .lineLimit(1)
        }
    }

    // Context menu exposed on long-press — quick actions that would otherwise
    // require opening a sheet. Keeping the most common actions (bookmark, share,
    // copy position) one long-press away reduces friction for power users.
    @ViewBuilder
    private func contextMenuItems(palette: ThemePalette) -> some View {
        Button {
            viewModel.toggleSaveCurrentDate()
        } label: {
            Label(
                viewModel.isCurrentDateSaved ? "Remove Bookmark" : "Bookmark",
                systemImage: viewModel.isCurrentDateSaved ? "bookmark.slash" : "bookmark"
            )
        }

        if let match = viewModel.bestMatch {
            ShareLink(
                item: viewModel.shareableCard(palette: palette),
                preview: SharePreview("PiDay", image: Image(systemName: "chart.bar.doc.horizontal"))
            ) {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Button {
                let pos = viewModel.displayedPosition(for: match.storedPosition)
                UIPasteboard.general.string = "digit \(pos)"
            } label: {
                Label("Copy Position", systemImage: "doc.on.doc")
            }
        }

        Button { onFreeSearch() } label: {
            Label("Search Pi Digits", systemImage: "magnifyingglass")
        }
    }

    // MARK: - Helpers

    // WHY palette parameter instead of a stored palette: SwiftUI view helpers
    // that return Color must derive their value from an argument rather than
    // a @State or @Environment read, so the function remains a pure mapping.
    private func heatColor(palette: ThemePalette) -> Color {
        switch viewModel.resultHeatLevel {
        case .hot:   return palette.heatHot
        case .warm:  return palette.heatWarm
        case .cool:  return palette.heatCool
        case .faint: return palette.heatFaint
        case .none:  return palette.mutedInk
        }
    }

    // WHY private static let formatter: DateFormatter is expensive to allocate
    // (it parses locale data on first use). Caching it as a static avoids
    // a fresh allocation on every render pass.
    // WHY dateStyle = .medium: unlike a fixed dateFormat string (which always
    // produces English month abbreviations), dateStyle respects the device locale.
    // A German device will show "19. März 2026"; a Japanese device "2026/03/19".
    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = .autoupdatingCurrent
        return f
    }()

    private func shortDate(_ date: Date) -> String {
        Self.shortDateFormatter.string(from: date)
    }
}

// MARK: - HeatIndicatorView

// Signal-bar style indicator: 4 bars of increasing height, left-to-right,
// bottom-aligned. The number of lit bars encodes the heat level — the same
// mental model as Wi-Fi or cellular signal strength.
//
// WHY bottom-aligned: aligning to .bottom gives the bars their staircase
// silhouette, which is the conventional signal-strength visual language.
// Center or top alignment destroys the shape entirely at this small scale.
private struct HeatIndicatorView: View {
    let heatLevel: PiHeatLevel
    let color: Color

    // Heights grow left → right so more bars = stronger signal = earlier in pi.
    private static let barHeights: [CGFloat] = [5, 7, 9, 11]

    private var litCount: Int {
        switch heatLevel {
        case .none:  return 0
        case .faint: return 1
        case .cool:  return 2
        case .warm:  return 3
        case .hot:   return 4
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(index < litCount ? color : color.opacity(0.20))
                    .frame(width: 3.5, height: Self.barHeights[index])
                    .animation(.easeOut(duration: 0.25).delay(Double(index) * 0.04), value: litCount)
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        switch heatLevel {
        case .none:  return "not found"
        case .faint: return "found late in pi"
        case .cool:  return "found in pi"
        case .warm:  return "found early in pi"
        case .hot:   return "found very early in pi"
        }
    }
}
