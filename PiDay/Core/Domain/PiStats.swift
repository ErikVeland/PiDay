import Foundation

struct PiStats: Sendable, Codable, Equatable {
    struct ExtremeMatch: Sendable, Codable, Equatable {
        let date: String
        let position: Int
        let format: DateFormatOption
        let query: String
    }

    struct MonthAggregate: Sendable, Codable, Equatable {
        let month: Int
        let averagePosition: Int
        let dateCount: Int
    }

    struct DayOfMonthAggregate: Sendable, Codable, Equatable {
        let day: Int
        let averagePosition: Int
        let dateCount: Int
    }

    struct FormatUpset: Sendable, Codable, Equatable {
        let date: String
        let bestFormat: DateFormatOption
        let bestPosition: Int
        let worstFormat: DateFormatOption
        let worstPosition: Int
        let spread: Int
    }

    struct QueryOddity: Sendable, Codable, Equatable {
        let date: String
        let position: Int
        let format: DateFormatOption
        let query: String
        let score: Int
    }

    let earliestMatch: ExtremeMatch?
    let latestMatch: ExtremeMatch?
    let averagePosition: Int
    let formatSuccessRate: [DateFormatOption: Double]
    let totalDatesMatched: Int
    let maxDigitReached: Int
    let piDayStats: [Int: Int] // Year: Position
    let bestDatePositions: [Int]
    let topEarliestDates: [ExtremeMatch]
    let luckiestMonth: MonthAggregate?
    let hardestMonth: MonthAggregate?
    let luckiestDayOfMonth: DayOfMonthAggregate?
    let hardestDayOfMonth: DayOfMonthAggregate?
    let biggestFormatUpset: FormatUpset?
    let longestRepeatRun: QueryOddity?
    let mostUniqueDigits: QueryOddity?
}

enum DateBattleWinner: Equatable {
    case left
    case right
    case tie
}

struct DateBattleContender: Equatable {
    let date: Date
    let summary: DateLookupSummary
    let displayedPosition: Int?
    let percentileLabel: String

    var bestMatch: BestPiMatch? { summary.bestMatch }
    var isFound: Bool { bestMatch != nil }
}

struct DateBattleResult: Equatable {
    let left: DateBattleContender
    let right: DateBattleContender
    let winner: DateBattleWinner
    let winningMargin: Int?
    let verdict: String

    var hasWinner: Bool {
        winner != .tie
    }
}

enum ShareCardStyle: String, CaseIterable, Identifiable {
    case classic
    case nerd
    case battle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return "Classic"
        case .nerd: return "Nerd"
        case .battle: return "Battle"
        }
    }

    var symbolName: String {
        switch self {
        case .classic: return "square.and.arrow.up"
        case .nerd: return "chart.bar.xaxis"
        case .battle: return "bolt.shield"
        }
    }
}

enum PiDelightCopy {
    static func rarityLabel(for storedPosition: Int?, among allPositions: [Int]) -> String {
        guard let storedPosition, !allPositions.isEmpty else { return "Unranked" }
        let lowerCount = allPositions.filter { $0 <= storedPosition }.count
        let percentile = max(1, Int((Double(lowerCount) / Double(allPositions.count)) * 100))
        return "Top \(percentile)%"
    }

    static func verdict(for left: DateBattleContender, right: DateBattleContender, margin: Int?) -> String {
        switch (left.displayedPosition, right.displayedPosition) {
        case let (lhs?, rhs?):
            if lhs == rhs {
                return "It’s a dead heat. Pi refuses to pick a favorite."
            }
            let winnerLabel = lhs < rhs ? "Left date" : "Right date"
            let loserLabel = lhs < rhs ? "right date" : "left date"
            if let margin, margin < 1_000 {
                return "\(winnerLabel) squeaks past the \(loserLabel) by only \(margin.formatted()) digits."
            }
            if let margin, margin < 1_000_000 {
                return "\(winnerLabel) wins comfortably, beating the \(loserLabel) by \(margin.formatted()) digits."
            }
            return "\(winnerLabel) absolutely steamrolls the \(loserLabel). Pi can be ruthless."
        case (_?, nil):
            return "Left date wins by existing at all. Brutal, but fair."
        case (nil, _?):
            return "Right date wins by existing at all. Brutal, but fair."
        case (nil, nil):
            return "Neither date lands an exact hit here. Pi remains mysterious."
        }
    }

    static func detailFact(for date: Date, bestMatch: BestPiMatch?) -> String? {
        let calendar = Calendar(identifier: .gregorian)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)

        if month == 3 && day == 14 {
            return "March 14 is Pi Day royalty. Naturally it gets special treatment around here."
        }
        if month == 2 && day == 29 {
            return "Leap day only shows up when the calendar feels extra mischievous."
        }
        if let bestMatch, longestRepeatedRun(in: bestMatch.query) >= 3 {
            return "That query has a satisfyingly repetitive streak. Pi loves a good pattern."
        }
        if let bestMatch, bestMatch.storedPosition < 1_000 {
            return "That’s an absurdly early hit. You basically found a unicorn."
        }
        if let bestMatch, bestMatch.storedPosition > 1_000_000_000 {
            return "Pi buried this one deep. Commitment was required."
        }
        return nil
    }

    static func freeSearchReaction(for query: String) -> String? {
        switch query {
        case "42": return "Deep thought approves."
        case "404": return "Sequence found. Error joke denied."
        case "1337": return "Elite digits detected."
        case "8675309": return "Jenny mode unlocked."
        default: return nil
        }
    }

    private static func longestRepeatedRun(in query: String) -> Int {
        var longest = 0
        var current = 0
        var previous: Character?

        for ch in query {
            if ch == previous {
                current += 1
            } else {
                current = 1
                previous = ch
            }
            longest = max(longest, current)
        }

        return longest
    }
}
