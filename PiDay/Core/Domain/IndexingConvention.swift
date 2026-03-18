import Foundation

// WHY: How we label digit positions is a user-facing preference, not a data concern.
// Keeping it in Domain makes it available to both ViewModel and View layers.
enum IndexingConvention: String, CaseIterable, Identifiable {
    case oneBased
    case zeroBased

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneBased:
            return "1-based"
        case .zeroBased:
            return "0-based"
        }
    }

    var explainer: String {
        switch self {
        case .oneBased:
            return "Digit 1 is the first digit after the decimal point."
        case .zeroBased:
            return "Digit 0 is the first digit after the decimal point."
        }
    }

    func displayPosition(for storedPosition: Int) -> Int {
        switch self {
        case .oneBased:
            return storedPosition
        case .zeroBased:
            return storedPosition - 1
        }
    }
}
