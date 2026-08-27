import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private var appCoordinator: AppCoordinator?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        self.window = window

        let navigationController = UINavigationController()
        navigationController.navigationBar.prefersLargeTitles = true

        let apiClient = APIClient(
            baseURL: AppEnvironment.claimsBaseURL,
            pinnedHost: AppEnvironment.claimsHost
        )
        let claimService = ClaimService(apiClient: apiClient, cache: ClaimCache())

        let coordinator = AppCoordinator(navigationController: navigationController, claimService: claimService)
        self.appCoordinator = coordinator
        coordinator.start()

        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        return true
    }
}
