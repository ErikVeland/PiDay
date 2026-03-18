import Foundation

// WHY: These are DTOs (Data Transfer Objects) — their only job is to decode the
// bundled JSON file. Keeping them in Core/Data separates "what the file looks like
// on disk" from "what our domain cares about" (PiMatch.swift).
//
// If the JSON format ever changes, only this file needs updating.

struct PiFormatMatch: Codable, Equatable {
    let query: String
    let position: Int
    let excerpt: String
}

struct PiDateRecord: Codable, Equatable {
    let date: String
    let formats: [DateFormatOption: PiFormatMatch]

    private enum CodingKeys: String, CodingKey {
        case date
        case formats
    }

    init(date: String, formats: [DateFormatOption: PiFormatMatch]) {
        self.date = date
        self.formats = formats
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)
        let rawFormats = try container.decode([String: PiFormatMatch].self, forKey: .formats)
        formats = Dictionary(
            uniqueKeysWithValues: rawFormats.compactMap { key, value in
                guard let format = DateFormatOption(rawValue: key) else { return nil }
                return (format, value)
            }
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        let rawFormats = Dictionary(uniqueKeysWithValues: formats.map { ($0.key.rawValue, $0.value) })
        try container.encode(rawFormats, forKey: .formats)
    }
}

struct PiIndexMetadata: Codable, Equatable {
    let startYear: Int
    let endYear: Int
    let indexing: String
    let excerptRadius: Int
    let generatedAt: String
    let source: String
}

struct PiIndexPayload: Codable, Equatable {
    let metadata: PiIndexMetadata
    let dates: [String: PiDateRecord]
}
