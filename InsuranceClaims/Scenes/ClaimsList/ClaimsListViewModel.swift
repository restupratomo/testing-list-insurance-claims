import Foundation

/// Drives the claims list screen: paginated loading, search filtering and
/// navigation to the detail screen, all independent of any UI framework so it
/// can be unit tested without spinning up Texture or UIKit.
final class ClaimsListViewModel {

    enum State {
        case idle
        case loading
        case loaded
        case error(String)
    }

    private(set) var state: State = .idle {
        didSet { onStateChange?(state) }
    }

    /// Every claim fetched so far, in page order.
    private(set) var claims: [Claim] = []

    /// The claims actually shown to the user: all of `claims` when there is no
    /// active search term, or the subset matching it otherwise.
    private(set) var visibleClaims: [Claim] = [] {
        didSet { onClaimsChange?() }
    }

    var onStateChange: ((State) -> Void)?
    var onClaimsChange: (() -> Void)?

    private let claimService: ClaimServiceProtocol
    private weak var coordinator: AppCoordinator?

    private var currentPage = 1
    private var hasMorePages = true
    private var isLoadingPage = false
    private var searchQuery = ""

    init(claimService: ClaimServiceProtocol, coordinator: AppCoordinator?) {
        self.claimService = claimService
        self.coordinator = coordinator
    }

    func loadFirstPage() {
        guard claims.isEmpty else { return }
        currentPage = 1
        hasMorePages = true
        loadNextPage()
    }

    func refresh() {
        currentPage = 1
        hasMorePages = true
        claims = []
        loadNextPage()
    }

    /// Called by the list as the user scrolls near the bottom.
    func loadMoreIfNeeded(currentIndex: Int) {
        guard hasMorePages, !isLoadingPage else { return }
        guard currentIndex >= visibleClaims.count - 3 else { return }
        loadNextPage()
    }

    func search(_ query: String) {
        searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        applyFilter()
    }

    func selectClaim(at index: Int) {
        guard visibleClaims.indices.contains(index) else { return }
        coordinator?.showDetail(for: visibleClaims[index])
    }

    private func loadNextPage() {
        isLoadingPage = true
        state = .loading

        claimService.fetchClaims(page: currentPage) { [weak self] result in
            guard let self = self else { return }
            self.isLoadingPage = false

            switch result {
            case .success(let newClaims):
                self.hasMorePages = newClaims.count == claimsPageSize
                self.currentPage += 1
                self.claims.append(contentsOf: newClaims)
                self.applyFilter()
                self.state = .loaded
            case .failure(let error):
                self.state = .error(error.userMessage)
            }
        }
    }

    private func applyFilter() {
        if searchQuery.isEmpty {
            visibleClaims = claims
        } else {
            visibleClaims = claims.filter {
                $0.title.range(of: searchQuery, options: .caseInsensitive) != nil ||
                $0.description.range(of: searchQuery, options: .caseInsensitive) != nil
            }
        }
    }
}
