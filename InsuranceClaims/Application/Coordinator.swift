import UIKit

/// A node in the app's navigation graph. Coordinators own the navigation
/// controller they push onto and are responsible for wiring up and presenting
/// the scenes that belong to their flow (MVVM-C).
protocol Coordinator: AnyObject {
    var navigationController: UINavigationController { get }
    func start()
}
