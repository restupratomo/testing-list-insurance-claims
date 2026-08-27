@testable import InsuranceClaims
import Nimble
import Quick
import UIKit

private final class NoOpClaimService: ClaimServiceProtocol {
    func fetchClaims(page: Int, completion: @escaping (Result<[Claim], NetworkError>) -> Void) {
        completion(.success([]))
    }
}

final class AppCoordinatorSpec: QuickSpec {
    override class func spec() {
        describe("AppCoordinator") {
            var navigationController: UINavigationController!
            var sut: AppCoordinator!

            beforeEach {
                navigationController = UINavigationController()
                sut = AppCoordinator(navigationController: navigationController, claimService: NoOpClaimService())
            }

            describe("start") {
                it("sets the claims list as the root view controller") {
                    sut.start()
                    expect(navigationController.viewControllers).to(haveCount(1))
                    expect(navigationController.viewControllers.first).to(beAKindOf(ClaimsListViewController.self))
                }
            }

            describe("showDetail") {
                it("pushes a claim detail view controller for the given claim") {
                    sut.start()
                    let claim = Claim(claimantId: 1, id: 1, title: "Water damage", description: "Pipe burst")

                    sut.showDetail(for: claim)

                    expect(navigationController.viewControllers).to(haveCount(2))
                    expect(navigationController.viewControllers.last).to(beAKindOf(ClaimDetailViewController.self))
                    expect(navigationController.topViewController?.title).to(equal("Claim #1"))
                }
            }
        }
    }
}
