import Foundation
import AppKit

public enum UpdateChannel: String, Codable, CaseIterable, Identifiable {
    case stable
    case beta

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .stable: return "Stable"
        case .beta: return "Beta"
        }
    }
}

public struct AppUpdate: Identifiable {
    public let id: String
    public let version: String
    public let releaseNotes: String
    public let downloadURL: URL
    public let publishedAt: Date
    public let isPrerelease: Bool
    public let downloadSize: Int64?
    public let tagName: String

    public init(
        id: String,
        version: String,
        releaseNotes: String,
        downloadURL: URL,
        publishedAt: Date,
        isPrerelease: Bool = false,
        downloadSize: Int64? = nil,
        tagName: String = ""
    ) {
        self.id = id
        self.version = version
        self.releaseNotes = releaseNotes
        self.downloadURL = downloadURL
        self.publishedAt = publishedAt
        self.isPrerelease = isPrerelease
        self.downloadSize = downloadSize
        self.tagName = tagName
    }
}

public final class UpdateChecker {
    public static let shared = UpdateChecker()

    private let githubRepo = "programsmagic/mac-xbar"
    private let currentVersion: String
    private var checkTimer: DispatchSourceTimer?
    private let storage = Storage.shared
    private let lastCheckKey = "last_update_check"
    private let autoCheckKey = "auto_check_updates"
    private let channelKey = "update_channel"

    private init() {
        self.currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0.0"
    }

    public var autoChecksEnabled: Bool {
        get { (try? storage.load(Bool.self, forKey: autoCheckKey)) ?? true }
        set {
            try? storage.save(newValue, forKey: autoCheckKey)
            if newValue {
                startPeriodicChecks()
            } else {
                stopPeriodicChecks()
            }
        }
    }

    public var channel: UpdateChannel {
        get { (try? storage.load(UpdateChannel.self, forKey: channelKey)) ?? .stable }
        set {
            try? storage.save(newValue, forKey: channelKey)
            if autoChecksEnabled {
                startPeriodicChecks()
            }
        }
    }

    public func startPeriodicChecks(interval: TimeInterval = 3600 * 6) {
        checkTimer?.cancel()
        guard autoChecksEnabled else { return }
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(60000))
        timer.setEventHandler { [weak self] in
            Task {
                _ = await self?.checkForUpdate()
            }
        }
        timer.resume()
        checkTimer = timer
    }

    public func stopPeriodicChecks() {
        checkTimer?.cancel()
        checkTimer = nil
    }

    public func checkForUpdate() async -> AppUpdate? {
        saveLastCheckDate()
        switch channel {
        case .stable:
            return await fetchLatestRelease(releasesURL: "https://api.github.com/repos/\(githubRepo)/releases/latest")
        case .beta:
            return await fetchNewestFromAll()
        }
    }

    private func fetchNewestFromAll() async -> AppUpdate? {
        guard let url = URL(string: "https://api.github.com/repos/\(githubRepo)/releases?per_page=10") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.addValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let releases = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return nil
            }

            var newest: AppUpdate?
            for release in releases {
                guard let tagName = release["tag_name"] as? String else { continue }
                let version = tagName.replacingOccurrences(of: "v", with: "")
                let isPrerelease = release["prerelease"] as? Bool ?? false

                guard isNewerVersion(version) else { continue }

                let candidate = makeUpdate(from: release, tagName: tagName, version: version, isPrerelease: isPrerelease)
                if newest == nil || isVersionNewer(candidate.version, than: newest!.version) {
                    newest = candidate
                }
            }

            if newest != nil {
                saveLastCheckDate()
            }
            return newest
        } catch {
            Logger.shared.error("Update check failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchLatestRelease(releasesURL: String) async -> AppUpdate? {
        guard let url = URL(string: releasesURL) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.addValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }

            guard let tagName = json["tag_name"] as? String else {
                return nil
            }

            let version = tagName.replacingOccurrences(of: "v", with: "")

            guard isNewerVersion(version) else {
                return nil
            }

            let update = makeUpdate(from: json, tagName: tagName, version: version, isPrerelease: false)
            return update

        } catch {
            Logger.shared.error("Update check failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func makeUpdate(from json: [String: Any], tagName: String, version: String, isPrerelease: Bool) -> AppUpdate {
        let releaseNotes = json["body"] as? String ?? "No release notes"
        let publishedAtString = json["published_at"] as? String ?? ""
        let publishedAt = ISO8601DateFormatter().date(from: publishedAtString) ?? Date()

        var downloadURL = URL(string: "https://github.com/\(githubRepo)/releases/latest")!
        var downloadSize: Int64?

        if let assets = json["assets"] as? [[String: Any]] {
            for asset in assets {
                if let name = asset["name"] as? String, name.hasSuffix(".dmg"),
                   let browserDownloadURL = asset["browser_download_url"] as? String,
                   let url = URL(string: browserDownloadURL) {
                    downloadURL = url
                    downloadSize = (asset["size"] as? Int).map { Int64($0) }
                    break
                }
            }
        }

        return AppUpdate(
            id: tagName,
            version: version,
            releaseNotes: releaseNotes,
            downloadURL: downloadURL,
            publishedAt: publishedAt,
            isPrerelease: isPrerelease,
            downloadSize: downloadSize,
            tagName: tagName
        )
    }

    public func openDownloadPage(_ update: AppUpdate) {
        NSWorkspace.shared.open(update.downloadURL)
    }

    public func lastCheckDate() -> Date? {
        try? storage.load(Date.self, forKey: lastCheckKey)
    }

    private func saveLastCheckDate() {
        try? storage.save(Date(), forKey: lastCheckKey)
    }

    public func isNewerVersion(_ remoteVersion: String) -> Bool {
        isVersionNewer(remoteVersion, than: currentVersion)
    }

    private func isVersionNewer(_ candidate: String, than current: String) -> Bool {
        let currentParts = current.split(separator: ".").map { Int($0) ?? 0 }
        let remoteParts = candidate.split(separator: ".").map { Int($0) ?? 0 }

        for i in 0..<max(currentParts.count, remoteParts.count) {
            let c = i < currentParts.count ? currentParts[i] : 0
            let r = i < remoteParts.count ? remoteParts[i] : 0
            if r > c { return true }
            if r < c { return false }
        }
        return false
    }
}
