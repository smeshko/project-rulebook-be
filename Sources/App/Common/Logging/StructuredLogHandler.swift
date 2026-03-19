import Foundation
import Logging

/// A `LogHandler` that outputs structured JSON log entries for production environments.
///
/// Each log line is a single JSON object containing:
/// - `timestamp`: ISO 8601 formatted date
/// - `level`: Log level string (trace, debug, info, notice, warning, error, critical)
/// - `message`: The log message
/// - `metadata`: Merged metadata dictionary (logger-level + per-message)
/// - `label`: Logger label identifying the subsystem
///
/// The `correlation_id` field from metadata is promoted to a top-level key for easy
/// filtering in log aggregation systems.
public struct StructuredLogHandler: LogHandler {
    public var logLevel: Logger.Level
    public var metadata: Logger.Metadata = [:]
    public var metadataProvider: Logger.MetadataProvider?

    private let label: String
    private let stream: TextOutputStream

    public init(label: String, logLevel: Logger.Level = .info) {
        self.label = label
        self.logLevel = logLevel
        self.stream = StderrOutputStream()
    }

    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        // Merge logger-level metadata, provider metadata, and per-message metadata
        let providerMetadata = self.metadataProvider?.get() ?? [:]
        let baseWithProvider = Self.mergeMetadata(base: self.metadata, override: providerMetadata)
        let mergedMetadata = Self.mergeMetadata(base: baseWithProvider, override: metadata)

        var entry: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "level": level.rawValue,
            "message": "\(message)",
            "label": label,
        ]

        // Promote correlation_id to top-level for easy log filtering
        if case let .string(correlationID) = mergedMetadata["correlation_id"] {
            entry["correlation_id"] = correlationID
        }

        // Convert remaining metadata to a serializable dictionary
        if !mergedMetadata.isEmpty {
            entry["metadata"] = Self.convertMetadata(mergedMetadata)
        }

        // Serialize to JSON
        if let jsonData = try? JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            var stream = self.stream
            stream.write(jsonString + "\n")
        }
    }

    // MARK: - Private Helpers

    private static func mergeMetadata(
        base: Logger.Metadata,
        override: Logger.Metadata?
    ) -> Logger.Metadata {
        guard let override = override else { return base }
        return base.merging(override, uniquingKeysWith: { _, new in new })
    }

    private static func convertMetadata(_ metadata: Logger.Metadata) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in metadata {
            result[key] = convertMetadataValue(value)
        }
        return result
    }

    private static func convertMetadataValue(_ value: Logger.MetadataValue) -> Any {
        switch value {
        case .string(let str):
            return str
        case .stringConvertible(let convertible):
            return convertible.description
        case .dictionary(let dict):
            return convertMetadata(dict)
        case .array(let array):
            return array.map { convertMetadataValue($0) }
        }
    }
}

// MARK: - Stderr Output Stream

private struct StderrOutputStream: TextOutputStream {
    mutating func write(_ string: String) {
        FileHandle.standardError.write(Data(string.utf8))
    }
}
