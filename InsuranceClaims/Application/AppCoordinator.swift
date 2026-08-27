import UIKit

/// Owns the app's single navigation flow: claims list -> claim detail.
final class AppCoordinator: Coordinator {
    let navigationController: UINavigationController
    private let claimService: ClaimServiceProtocol

    init(navigationController: UINavigationController, claimService: ClaimServiceProtocol) {
        self.navigationController = navigationController
        self.claimService = claimService
    }

    func start() {
        let viewModel = ClaimsListViewModel(claimService: claimService, coordinator: self)
        let listViewController = ClaimsListViewController(viewModel: viewModel)
        navigationController.setViewControllers([listViewController], animated: false)
    }

    func showDetail(for claim: Claim) {
        let viewModel = ClaimDetailViewModel(claim: claim)
        let detailViewController = ClaimDetailViewController(viewModel: viewModel)
        navigationController.pushViewController(detailViewController, animated: true)
    }
}
