import Foundation

enum ExportDates {
    static func encodeStrategy() -> JSONEncoder.DateEncodingStrategy {
        .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(fractional.string(from: date))
        }
    }

    static func decodeStrategy() -> JSONDecoder.DateDecodingStrategy {
        .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = fractional.date(from: raw) { return date }
            if let date = wholeSeconds.date(from: raw) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognized ISO8601 date: \(raw)"
            )
        }
    }

    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let wholeSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
