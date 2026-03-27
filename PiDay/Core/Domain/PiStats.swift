import Foundation

struct PiStats: Sendable, Codable, Equatable {
    struct ExtremeMatch: Sendable, Codable, Equatable {
        let date: String
        let position: Int
        let format: DateFormatOption
        let query: String
    }

    let earliestMatch: ExtremeMatch?
    let latestMatch: ExtremeMatch?
    let averagePosition: Int
    let formatSuccessRate: [DateFormatOption: Double]
    let totalDatesMatched: Int
    let maxDigitReached: Int
    let piDayStats: [Int: Int] // Year: Position
}
