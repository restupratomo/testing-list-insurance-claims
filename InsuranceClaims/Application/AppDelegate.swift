import IQKeyboardManagerSwift
import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private var appCoordinator: AppCoordinator?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        configureKeyboardManager()

        let window = UIWindow(frame: UIScreen.main.bounds)
        self.window = window

        let navigationController = UINavigationController()
        navigationController.navigationBar.prefersLargeTitles = true
        // The default back-button blue reads as an accent color the rest of
        // the app doesn't use; match the label color instead.
        navigationController.navigationBar.tintColor = .adaptiveLabel

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

    /// Keeps the keyboard from covering the focused text field/view (e.g. the
    /// claims search bar) by shifting the view up automatically, instead of
    /// each screen having to implement its own keyboard-avoidance logic.
    private func configureKeyboardManager() {
        IQKeyboardManager.shared.enable = true
        IQKeyboardManager.shared.shouldResignOnTouchOutside = true
        // Debug logging must never ship to production — it would print view
        // hierarchy details to the console on every device.
        IQKeyboardManager.shared.enableDebugging = false
    }
}
