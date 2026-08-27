import Foundation

/// Central place for the API endpoint the app talks to. The host itself is
/// obfuscated so it isn't sitting as a plain-text string in the shipped binary.
enum AppEnvironment {
    static let claimsHost = ObfuscatedString("jsonplaceholder.typicode.com").value

    static var claimsBaseURL: URL {
        URL(string: "https://\(claimsHost)")!
    }
}
