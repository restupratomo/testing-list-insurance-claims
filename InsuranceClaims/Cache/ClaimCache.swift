import Foundation

/// Persists claims per page so the list can render instantly on repeat visits
/// without waiting on the network, and only asks the network for a page again
/// once that page's cached entry has gone stale.
protocol ClaimCacheProtocol {
    func claims(forPage page: Int) -> [Claim]?
    func store(_ claims: [Claim], forPage page: Int)
    func invalidate(page: Int)
    func invalidateAll()
}

final class ClaimCache: ClaimCacheProtocol {
    private struct CacheEntry: Codable {
        let claims: [Claim]
        let storedAt: Date
    }

    private let fileManager: FileManager
    private let directoryURL: URL
    private let timeToLive: TimeInterval

    /// - Parameter timeToLive: how long a cached page is considered fresh before
    ///   it is treated as empty and re-fetched from the network.
    init(fileManager: FileManager = .default, timeToLive: TimeInterval = 5 * 60) {
        self.fileManager = fileManager
        self.timeToLive = timeToLive

        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.directoryURL = cachesDirectory.appendingPathComponent("ClaimsCache", isDirectory: true)
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func claims(forPage page: Int) -> [Claim]? {
        guard let data = try? Data(contentsOf: fileURL(forPage: page)),
              let entry = try? JSONDecoder().decode(CacheEntry.self, from: data) else {
            return nil
        }

        guard Date().timeIntervalSince(entry.storedAt) < timeToLive else {
            return nil
        }

        return entry.claims
    }

    func store(_ claims: [Claim], forPage page: Int) {
        let entry = CacheEntry(claims: claims, storedAt: Date())
        guard let data = try? JSONEncoder().encode(entry) else { return }
        try? data.write(to: fileURL(forPage: page), options: .atomic)
    }

    func invalidate(page: Int) {
        try? fileManager.removeItem(at: fileURL(forPage: page))
    }

    func invalidateAll() {
        try? fileManager.removeItem(at: directoryURL)
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func fileURL(forPage page: Int) -> URL {
        directoryURL.appendingPathComponent("page-\(page).json")
    }
}
