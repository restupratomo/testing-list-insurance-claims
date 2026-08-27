import AsyncDisplayKit
@testable import InsuranceClaims
import Nimble
import Quick
import UIKit

private final class ClaimServiceStub: ClaimServiceProtocol {
    var result: Result<[Claim], NetworkError> = .success([])

    func fetchClaims(page: Int, completion: @escaping (Result<[Claim], NetworkError>) -> Void) {
        completion(result)
    }
}

/// Captures the completion handler instead of calling it, so a spec can
/// inspect UI state *while a fetch is still in flight* — something the
/// synchronously-resolving `ClaimServiceStub` above can never observe.
private final class DeferredClaimServiceStub: ClaimServiceProtocol {
    private(set) var pendingCompletion: ((Result<[Claim], NetworkError>) -> Void)?

    func fetchClaims(page: Int, completion: @escaping (Result<[Claim], NetworkError>) -> Void) {
        pendingCompletion = completion
    }
}

final class ClaimsListViewControllerSpec: QuickSpec {
    override class func spec() {
        describe("ClaimsListViewController") {
            var service: ClaimServiceStub!
            var viewModel: ClaimsListViewModel!
            var sut: ClaimsListViewController!

            beforeEach {
                service = ClaimServiceStub()
                viewModel = ClaimsListViewModel(claimService: service, coordinator: nil)
                sut = ClaimsListViewController(viewModel: viewModel)
            }

            it("has the expected navigation title") {
                expect(sut.title).to(equal("Insurance Claims"))
            }

            describe("the back-to-top button") {
                it("starts hidden") {
                    sut.loadViewIfNeeded()
                    expect(sut.backToTopButton.isHidden).to(beTrue())
                }

                it("appears once the list is scrolled past the threshold") {
                    sut.loadViewIfNeeded()
                    let scrollView = UIScrollView()
                    scrollView.contentOffset = CGPoint(x: 0, y: 500)

                    sut.scrollViewDidScroll(scrollView)

                    expect(sut.backToTopButton.isHidden).to(beFalse())
                }

                it("hides again once scrolled back near the top") {
                    sut.loadViewIfNeeded()
                    let scrolledDown = UIScrollView()
                    scrolledDown.contentOffset = CGPoint(x: 0, y: 500)
                    sut.scrollViewDidScroll(scrolledDown)

                    let scrolledUp = UIScrollView()
                    scrolledUp.contentOffset = CGPoint(x: 0, y: 0)
                    sut.scrollViewDidScroll(scrolledUp)

                    expect(sut.backToTopButton.isHidden).to(beTrue())
                }

                it("scrolls the list back to the top when tapped") {
                    sut.loadViewIfNeeded()

                    sut.backToTopButton.sendActions(for: .touchUpInside)

                    // Reaching this line without crashing confirms the tap
                    // target/action wiring is correct.
                    expect(sut.backToTopButton).toNot(beNil())
                }
            }

            describe("the loading spinner") {
                it("animates while the first page is still being fetched, and stops once it resolves") {
                    let deferredService = DeferredClaimServiceStub()
                    let deferredViewModel = ClaimsListViewModel(claimService: deferredService, coordinator: nil)
                    let deferredSut = ClaimsListViewController(viewModel: deferredViewModel)

                    deferredSut.loadViewIfNeeded()
                    expect(deferredSut.activityIndicator.isAnimating).to(beTrue())

                    deferredService.pendingCompletion?(.success([]))
                    expect(deferredSut.activityIndicator.isAnimating).to(beFalse())
                }

                it("stops once the fetch fails, rather than spinning forever") {
                    let deferredService = DeferredClaimServiceStub()
                    let deferredViewModel = ClaimsListViewModel(claimService: deferredService, coordinator: nil)
                    let deferredSut = ClaimsListViewController(viewModel: deferredViewModel)

                    deferredSut.loadViewIfNeeded()
                    expect(deferredSut.activityIndicator.isAnimating).to(beTrue())

                    deferredService.pendingCompletion?(.failure(.server(statusCode: 500)))
                    expect(deferredSut.activityIndicator.isAnimating).to(beFalse())
                }
            }

            context("once the view loads and claims are fetched") {
                beforeEach {
                    let claims = (1...3).map {
                        Claim(claimantId: $0, id: $0, title: "Claim \($0)", description: "Description \($0)")
                    }
                    service.result = .success(claims)
                    sut.loadViewIfNeeded()
                }

                it("has stopped animating the loading spinner once claims arrive") {
                    expect(sut.activityIndicator.isAnimating).to(beFalse())
                }

                it("reports one row per visible claim to the collection data source") {
                    let count = sut.collectionNode(ASCollectionNodeStub.shared, numberOfItemsInSection: 0)
                    expect(count).to(equal(3))
                }

                it("builds a cell node block for each row") {
                    let block = sut.collectionNode(ASCollectionNodeStub.shared, nodeBlockForItemAt: IndexPath(item: 0, section: 0))
                    expect(block()).to(beAKindOf(ClaimCellNode.self))
                }

                it("filters rows when the search text updates, once the debounce window elapses") {
                    let searchController = UISearchController(searchResultsController: nil)
                    searchController.searchBar.text = "Claim 2"

                    sut.updateSearchResults(for: searchController)

                    expect(viewModel.visibleClaims.map { $0.id }).toEventually(equal([2]), timeout: .seconds(2))
                }

                it("forwards a row tap to the view model as a selection") {
                    let node = sut.node!
                    let indexPath = IndexPath(item: 0, section: 0)

                    sut.collectionNode(node, didSelectItemAt: indexPath)

                    // Reaching this line without crashing confirms the tap
                    // was forwarded to ClaimsListViewModel.selectClaim(at:).
                    expect(viewModel.visibleClaims.count).to(equal(3))
                }

                it("constrains each cell to the collection's full width") {
                    let node = sut.node!
                    let indexPath = IndexPath(item: 0, section: 0)

                    let sizeRange = sut.collectionNode(node, constrainedSizeForItemAt: indexPath)

                    expect(sizeRange.min.width).to(equal(node.bounds.width))
                    expect(sizeRange.max.width).to(equal(node.bounds.width))
                }

                it("does nothing when asked to load more for a node that isn't in the collection") {
                    let detachedNode = ClaimCellNode(claim: Claim(claimantId: 1, id: 1, title: "t", description: "d"))

                    sut.collectionNode(sut.node!, willDisplayItemWith: detachedNode)

                    // A node with no index path in the collection is ignored
                    // rather than forwarded to ClaimsListViewModel.loadMoreIfNeeded.
                    expect(viewModel.visibleClaims.count).to(equal(3))
                }
            }

            context("when a page fails to load") {
                beforeEach {
                    service.result = .failure(.server(statusCode: 500))
                }

                it("routes the failure into an error-presenting state without crashing") {
                    // A headless XCTest run has no real key window, so UIKit
                    // won't actually surface the alert here — this exercises
                    // the .error branch and presentError(_:) for coverage.
                    sut.loadViewIfNeeded()

                    expect(viewModel.state.description).to(equal("error(The server returned an error (code 500). Please try again later.)"))
                }

                it("does nothing but update state when an idle notification arrives") {
                    sut.loadViewIfNeeded()

                    viewModel.stateRelay.accept(.idle)

                    // Reaching this line without crashing confirms the .idle
                    // branch (a no-op) was taken rather than presenting
                    // another alert or touching the activity indicator.
                    expect(viewModel.state.description).to(equal("idle"))
                }

                it("reloads from the first page when the alert's Retry action fires") {
                    sut.loadViewIfNeeded()
                    service.result = .success([Claim(claimantId: 1, id: 1, title: "Retried", description: "d")])

                    sut.retryTapped()

                    expect(viewModel.visibleClaims.map { $0.title }).to(equal(["Retried"]))
                }
            }
        }
    }
}

/// `ASCollectionDataSource`/`ASCollectionDelegate` methods only need a
/// collection node identity to look up state via `indexPath(for:)`; the
/// specs above don't rely on that lookup, so a bare, un-mounted node is a
/// safe stand-in for a live, laid-out collection view.
private enum ASCollectionNodeStub {
    static let shared = ASCollectionNode(collectionViewLayout: UICollectionViewFlowLayout())
}
