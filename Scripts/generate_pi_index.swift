#!/usr/bin/swift

import Foundation

struct RawMatch: Decodable {
    let date: String
    let format: String
    let query: String
    let position: Int
    let excerpt: String
}

struct PiFormatMatch: Codable {
    let query: String
    let position: Int
    let excerpt: String
}

struct PiDateRecord: Codable {
    let date: String
    let formats: [String: PiFormatMatch]
}

struct PiIndexMetadata: Codable {
    let year: Int
    let indexing: String
    let excerptRadius: Int
    let generatedAt: String
    let source: String
}

struct PiIndexPayload: Codable {
    let metadata: PiIndexMetadata
    let dates: [String: PiDateRecord]
}

enum GeneratorError: Error, CustomStringConvertible {
    case usage
    case invalidYear(String)

    var description: String {
        switch self {
        case .usage:
            return "Usage: generate_pi_index.swift raw_matches.json output.json 2026"
        case let .invalidYear(value):
            return "Invalid year: \(value)"
        }
    }
}

func main() throws {
    let arguments = CommandLine.arguments
    guard arguments.count == 4 else {
        throw GeneratorError.usage
    }

    let inputPath = arguments[1]
    let outputPath = arguments[2]
    guard let year = Int(arguments[3]) else {
        throw GeneratorError.invalidYear(arguments[3])
    }

    let inputURL = URL(fileURLWithPath: inputPath)
    let outputURL = URL(fileURLWithPath: outputPath)
    let data = try Data(contentsOf: inputURL)
    let rawMatches = try JSONDecoder().decode([RawMatch].self, from: data)

    var grouped: [String: [String: PiFormatMatch]] = [:]
    for match in rawMatches where match.date.hasPrefix(String(year)) {
        grouped[match.date, default: [:]][match.format] = PiFormatMatch(
            query: match.query,
            position: match.position,
            excerpt: match.excerpt
        )
    }

    let dateRecords = Dictionary(
        uniqueKeysWithValues: grouped.map { date, formats in
            (date, PiDateRecord(date: date, formats: formats))
        }
    )

    let payload = PiIndexPayload(
        metadata: PiIndexMetadata(
            year: year,
            indexing: "one_based_after_decimal",
            excerptRadius: 16,
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            source: URL(fileURLWithPath: inputPath).lastPathComponent
        ),
        dates: dateRecords
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let outputData = try encoder.encode(payload)
    try outputData.write(to: outputURL)
}

do {
    try main()
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
