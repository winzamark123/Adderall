import Foundation

public struct SnapshotStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func userDefault() throws -> SnapshotStore {
        let applicationSupportURLs = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)

        guard let applicationSupportURL = applicationSupportURLs.first else {
            throw SnapshotStoreError.applicationSupportDirectoryUnavailable
        }

        return SnapshotStore(fileURL: applicationSupportURL.appending(path: "Adderail/controller-state.json"))
    }

    public func load() throws -> ControllerSnapshot? {
        if FileManager.default.fileExists(atPath: fileURL.path) == false {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(ControllerSnapshot.self, from: data)
    }

    public func save(_ snapshot: ControllerSnapshot) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
    }

    public func remove() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

public enum SnapshotStoreError: LocalizedError {
    case applicationSupportDirectoryUnavailable

    public var errorDescription: String? {
        switch self {
        case .applicationSupportDirectoryUnavailable:
            return "Could not locate the user application support directory."
        }
    }
}
