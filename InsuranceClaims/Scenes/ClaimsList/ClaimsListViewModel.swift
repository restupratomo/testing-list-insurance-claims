import Foundation
import RxRelay
import RxSwift

/// Minimum number of characters the user must type before a search query is
/// applied — short queries mostly just re-run the filter on almost every
/// claim, so waiting a few more keystrokes keeps the list from thrashing.
let minimumSearchQueryLength = 3

/// Drives the claims list screen: paginated loading, search filtering and
/// navigation to the detail screen, all independent of any UI framework so it
/// can be unit tested without spinning up Texture or UIKit.
///
/// State and the visible claims are exposed as Rx relays rather than plain
/// stored properties with change callbacks, so the view controller (or a
/// future SwiftUI/Rx-driven view) subscribes to updates instead of the view
/// model reaching back into it via closures.
final class ClaimsListViewModel {

    enum State {
        case idle
        case loading
        case loaded
        case error(String)
    }

    /// Current load/error state of the list. `state` is a synchronous,
    /// synchronously-testable snapshot of the same value as `stateObservable`.
    let stateRelay = BehaviorRelay<State>(value: .idle)
    var stateObservable: Observable<State> { stateRelay.asObservable() }
    var state: State { stateRelay.value }

    /// The claims actually shown to the user: all fetched claims when there
    /// is no active search term, or the subset matching it otherwise.
    let visibleClaimsRelay = BehaviorRelay<[Claim]>(value: [])
    var visibleClaimsObservable: Observable<[Claim]> { visibleClaimsRelay.asObservable() }
    var visibleClaims: [Claim] { visibleClaimsRelay.value }

    /// Every claim fetched so far, in page order (unfiltered).
    private(set) var claims: [Claim] = []

    private let claimService: ClaimServiceProtocol
    private weak var coordinator: AppCoordinator?

    private var currentPage = 1
    private var hasMorePages = true
    private var isLoadingPage = false
    private var searchQuery = ""

    private let searchQuerySubject = PublishSubject<String>()
    private let disposeBag = DisposeBag()

    /// - Parameter scheduler: where the debounced search runs. Defaults to
    ///   the main scheduler; specs inject a scheduler they control so search
    ///   behavior can be tested without waiting on real time.
    init(claimService: ClaimServiceProtocol, coordinator: AppCoordinator?, scheduler: SchedulerType = MainScheduler.instance) {
        self.claimService = claimService
        self.coordinator = coordinator

        searchQuerySubject
            .debounce(.milliseconds(300), scheduler: scheduler)
            .distinctUntilChanged()
            .subscribe(onNext: { [weak self] query in
                self?.searchQuery = query
                self?.applyFilter()
            })
            .disposed(by: disposeBag)
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

    /// Queues a search for `query`, debounced and applied once the user has
    /// typed at least `minimumSearchQueryLength` characters (an empty query
    /// is queued immediately so clearing the search bar restores the list
    /// without waiting on the debounce window).
    func search(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty || trimmed.count >= minimumSearchQueryLength else { return }
        searchQuerySubject.onNext(trimmed)
    }

    func selectClaim(at index: Int) {
        guard visibleClaims.indices.contains(index) else { return }
        coordinator?.showDetail(for: visibleClaims[index])
    }

    private func loadNextPage() {
        isLoadingPage = true
        stateRelay.accept(.loading)

        claimService.fetchClaims(page: currentPage) { [weak self] result in
            guard let self = self else { return }
            self.isLoadingPage = false

            switch result {
            case .success(let newClaims):
                self.hasMorePages = newClaims.count == claimsPageSize
                self.currentPage += 1
                self.claims.append(contentsOf: newClaims)
                self.applyFilter()
                self.stateRelay.accept(.loaded)
            case .failure(let error):
                self.stateRelay.accept(.error(error.userMessage))
            }
        }
    }

    private func applyFilter() {
        if searchQuery.isEmpty {
            visibleClaimsRelay.accept(claims)
        } else {
            let filtered = claims.filter {
                $0.title.range(of: searchQuery, options: .caseInsensitive) != nil ||
                $0.description.range(of: searchQuery, options: .caseInsensitive) != nil
            }
            visibleClaimsRelay.accept(filtered)
        }
    }
}
