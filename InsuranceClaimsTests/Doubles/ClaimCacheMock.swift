import Foundation
@testable import InsuranceClaims

final class ClaimCacheMock: ClaimCacheProtocol {
    private var storage: [Int: [Claim]] = [:]
    private(set) var storeCallCount = 0

    func claims(forPage page: Int) -> [Claim]? {
        storage[page]
    }

    func store(_ claims: [Claim], forPage page: Int) {
        storage[page] = claims
        storeCallCount += 1
    }

    func invalidate(page: Int) {
        storage[page] = nil
    }

    func invalidateAll() {
        storage.removeAll()
    }
}
