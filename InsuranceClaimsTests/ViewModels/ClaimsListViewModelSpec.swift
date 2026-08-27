import Quick
import Nimble
@testable import InsuranceClaims

private final class ClaimServiceStub: ClaimServiceProtocol {
    var pages: [Int: Result<[Claim], NetworkError>] = [:]
    private(set) var requestedPages: [Int] = []

    func fetchClaims(page: Int, completion: @escaping (Result<[Claim], NetworkError>) -> Void) {
        requestedPages.append(page)
        completion(pages[page] ?? .success([]))
    }
}

private func makeClaim(id: Int, title: String = "Claim", description: String = "Description") -> Claim {
    Claim(claimantId: id, id: id, title: title, description: description)
}

final class ClaimsListViewModelSpec: QuickSpec {
    override func spec() {
        describe("ClaimsListViewModel") {
            var service: ClaimServiceStub!
            var sut: ClaimsListViewModel!

            beforeEach {
                service = ClaimServiceStub()
                sut = ClaimsListViewModel(claimService: service, coordinator: nil)
            }

            context("loading the first page") {
                it("populates the visible claims with a full page of results") {
                    let firstPage = (1...claimsPageSize).map { makeClaim(id: $0) }
                    service.pages[1] = .success(firstPage)

                    sut.loadFirstPage()

                    expect(sut.visibleClaims).to(equal(firstPage))
                }

                it("does not request another page once already loaded") {
                    service.pages[1] = .success([makeClaim(id: 1)])
                    sut.loadFirstPage()
                    sut.loadFirstPage()

                    expect(service.requestedPages).to(equal([1]))
                }
            }

            context("when a page fails to load") {
                it("exposes the error's user-facing message as state") {
                    service.pages[1] = .failure(.server(statusCode: 500))

                    sut.loadFirstPage()

                    if case .error(let message) = sut.state {
                        expect(message).to(equal(NetworkError.server(statusCode: 500).userMessage))
                    } else {
                        fail("expected .error state, got \(sut.state)")
                    }
                }
            }

            context("pagination") {
                it("stops requesting further pages once a short page is returned") {
                    let fullPage = (1...claimsPageSize).map { makeClaim(id: $0) }
                    let shortPage = [makeClaim(id: 100)]
                    service.pages[1] = .success(fullPage)
                    service.pages[2] = .success(shortPage)

                    sut.loadFirstPage()
                    sut.loadMoreIfNeeded(currentIndex: fullPage.count - 1)
                    sut.loadMoreIfNeeded(currentIndex: 0)

                    expect(service.requestedPages).to(equal([1, 2]))
                }
            }

            context("search") {
                it("filters visible claims by title or description, case-insensitively") {
                    let claims = [
                        makeClaim(id: 1, title: "Vehicle damage", description: "Hit from behind"),
                        makeClaim(id: 2, title: "Water damage", description: "Pipe burst in kitchen")
                    ]
                    service.pages[1] = .success(claims)
                    sut.loadFirstPage()

                    sut.search("vehicle")

                    expect(sut.visibleClaims).to(equal([claims[0]]))
                }

                it("restores the full list when the search query is cleared") {
                    let claims = [makeClaim(id: 1, title: "Vehicle damage")]
                    service.pages[1] = .success(claims)
                    sut.loadFirstPage()

                    sut.search("vehicle")
                    sut.search("")

                    expect(sut.visibleClaims).to(equal(claims))
                }
            }
        }
    }
}

extension ClaimsListViewModel.State: CustomStringConvertible {
    public var description: String {
        switch self {
        case .idle: return "idle"
        case .loading: return "loading"
        case .loaded: return "loaded"
        case .error(let message): return "error(\(message))"
        }
    }
}
