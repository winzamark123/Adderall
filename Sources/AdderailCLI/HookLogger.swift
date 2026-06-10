import Foundation

struct HookLogger {
    private let fileURL: URL

    static func userDefault(provider: String = "claude") -> HookLogger? {
        guard let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            return nil
        }

        return HookLogger(fileURL: libraryURL.appending(path: "Logs/Adderail/\(provider)-hooks.log"))
    }

    func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(timestamp) \(message)\n"
        let data = Data(line.utf8)

        do {
            let directoryURL = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

            if FileManager.default.fileExists(atPath: fileURL.path) == false {
                try data.write(to: fileURL)
                return
            }

            let handle = try FileHandle(forWritingTo: fileURL)
            defer {
                try? handle.close()
            }

            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            return
        }
    }
}
