import Foundation

public protocol Storable: Codable {}

public final class Storage {
    public static let shared = Storage()

    private let fileManager: FileManager
    private let directory: URL

    private init() {
        self.fileManager = FileManager.default
        self.directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("mac-xbar", isDirectory: true)
        ensureDirectoryExists()
    }

    public func save<T: Storable>(_ value: T, forKey key: String) throws {
        let url = directory.appendingPathComponent(key + ".json")
        let data = try JSONEncoder().encode(value)
        try data.write(to: url)
    }

    public func load<T: Storable>(_ type: T.Type, forKey key: String) throws -> T? {
        let url = directory.appendingPathComponent(key + ".json")
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    public func remove(forKey key: String) throws {
        let url = directory.appendingPathComponent(key + ".json")
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    public func allKeys() throws -> [String] {
        let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return contents.compactMap { $0.deletingPathExtension().lastPathComponent }
    }

    private func ensureDirectoryExists() {
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}