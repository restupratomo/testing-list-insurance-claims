import Foundation

/// Describes a single REST endpoint the app talks to.
struct Endpoint {
    let path: String
    let queryItems: [URLQueryItem]

    func url(relativeTo baseURL: URL) -> URL? {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        return components?.url
    }
}

extension Endpoint {
    /// Claims list, paginated using the API's `_page` / `_limit` query parameters.
    static func claims(page: Int, pageSize: Int) -> Endpoint {
        Endpoint(
            path: "posts",
            queryItems: [
                URLQueryItem(name: "_page", value: String(page)),
                URLQueryItem(name: "_limit", value: String(pageSize))
            ]
        )
    }
}
