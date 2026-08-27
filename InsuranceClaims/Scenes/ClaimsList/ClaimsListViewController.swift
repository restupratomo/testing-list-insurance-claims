import AsyncDisplayKit
import Localize_Swift
import RxSwift

/// Claims list screen. Hosts an `ASCollectionNode` for cell-content prepared
/// off the main thread, a search bar for filtering, and a footer spinner for
/// pagination — all driven by `ClaimsListViewModel`'s Rx relays. Localized
/// strings follow the device's system language (Settings > General >
/// Language & Region); there is no in-app language switch.
final class ClaimsListViewController: ASDKViewController<ASCollectionNode> {

    /// How far down the list the user must scroll before the "back to top"
    /// button appears.
    private static let backToTopThreshold: CGFloat = 400

    private let viewModel: ClaimsListViewModel
    private let collectionNode: ASCollectionNode
    private let searchController = UISearchController(searchResultsController: nil)
    /// Internal rather than private so specs can assert on `isAnimating`
    /// directly instead of only inferring it from view model state.
    /// `.large` is iOS 13+; `.whiteLarge` is its iOS 12 predecessor, given a
    /// visible tint since white-on-white would otherwise be invisible.
    let activityIndicator: UIActivityIndicatorView = {
        let indicator: UIActivityIndicatorView
        if #available(iOS 13.0, *) {
            indicator = UIActivityIndicatorView(style: .large)
        } else {
            indicator = UIActivityIndicatorView(style: .whiteLarge)
        }
        indicator.color = .adaptiveLabel
        return indicator
    }()
    /// Internal rather than private so specs can assert on `isHidden`
    /// directly instead of driving a real scroll gesture.
    let backToTopButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("claims_list.back_to_top".localized(), for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        button.backgroundColor = .adaptiveLabel
        button.setTitleColor(.adaptiveBackground, for: .normal)
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 18, bottom: 10, right: 18)
        button.layer.cornerRadius = 20
        button.clipsToBounds = true
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    private let disposeBag = DisposeBag()

    init(viewModel: ClaimsListViewModel) {
        self.viewModel = viewModel

        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        self.collectionNode = ASCollectionNode(collectionViewLayout: layout)

        super.init(node: collectionNode)
        title = "claims_list.title".localized()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .adaptiveBackground
        collectionNode.backgroundColor = .adaptiveBackground
        collectionNode.dataSource = self
        collectionNode.delegate = self
        // Shown on the claim detail screen's back button once pushed; an
        // empty title collapses it down to just the chevron.
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)

        configureSearchController()
        configureLoadingIndicator()
        configureBackToTopButton()
        bindViewModel()

        viewModel.loadFirstPage()
    }

    private func configureSearchController() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "claims_list.search_placeholder".localized()
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    private func configureLoadingIndicator() {
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func configureBackToTopButton() {
        backToTopButton.addTarget(self, action: #selector(backToTopTapped), for: .touchUpInside)
        view.addSubview(backToTopButton)
        NSLayoutConstraint.activate([
            backToTopButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            backToTopButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    @objc private func backToTopTapped() {
        collectionNode.view.setContentOffset(
            CGPoint(x: 0, y: -collectionNode.view.adjustedContentInset.top),
            animated: true
        )
    }

    private func bindViewModel() {
        viewModel.stateObservable
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] state in
                guard let self = self else { return }
                switch state {
                case .idle:
                    break
                case .loading where self.viewModel.claims.isEmpty:
                    self.activityIndicator.startAnimating()
                case .loading, .loaded:
                    self.activityIndicator.stopAnimating()
                case .error(let message):
                    self.activityIndicator.stopAnimating()
                    self.presentError(message)
                }
            })
            .disposed(by: disposeBag)

        viewModel.visibleClaimsObservable
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.collectionNode.reloadData()
            })
            .disposed(by: disposeBag)
    }

    private func presentError(_ message: String) {
        present(makeErrorAlert(message), animated: true)
    }

    /// Split out from `presentError(_:)` so specs can fetch the alert and
    /// invoke its Retry action's handler directly, since UIKit won't deliver
    /// a real tap without a live window.
    func makeErrorAlert(_ message: String) -> UIAlertController {
        let alert = UIAlertController(
            title: "claims_list.error_alert.title".localized(),
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "action.retry".localized(), style: .default, handler: { [weak self] _ in
            self?.retryTapped()
        }))
        alert.addAction(UIAlertAction(title: "action.ok".localized(), style: .cancel))
        return alert
    }

    /// Split out from the alert action's closure so specs can call it
    /// directly instead of triggering a real tap on a presented alert.
    func retryTapped() {
        viewModel.refresh()
    }
}

// MARK: - ASCollectionDataSource

extension ClaimsListViewController: ASCollectionDataSource {
    func collectionNode(_ collectionNode: ASCollectionNode, numberOfItemsInSection section: Int) -> Int {
        viewModel.visibleClaims.count
    }

    func collectionNode(_ collectionNode: ASCollectionNode, nodeBlockForItemAt indexPath: IndexPath) -> ASCellNodeBlock {
        let claim = viewModel.visibleClaims[indexPath.item]
        return { ClaimCellNode(claim: claim) }
    }
}

// MARK: - ASCollectionDelegate

extension ClaimsListViewController: ASCollectionDelegateFlowLayout {
    func collectionNode(_ collectionNode: ASCollectionNode, didSelectItemAt indexPath: IndexPath) {
        collectionNode.deselectItem(at: indexPath, animated: true)
        viewModel.selectClaim(at: indexPath.item)
    }

    func collectionNode(_ collectionNode: ASCollectionNode, willDisplayItemWith node: ASCellNode) {
        guard let indexPath = collectionNode.indexPath(for: node) else { return }
        viewModel.loadMoreIfNeeded(currentIndex: indexPath.item)
    }

    // Flow layout's automatic sizing measures each cell at its intrinsic
    // content width, which packs rows side-by-side instead of stacking them.
    // Forcing every cell to the collection's full width keeps rows full-bleed.
    func collectionNode(
        _ collectionNode: ASCollectionNode,
        constrainedSizeForItemAt indexPath: IndexPath
    ) -> ASSizeRange {
        let width = collectionNode.bounds.width
        return ASSizeRange(
            min: CGSize(width: width, height: 0),
            max: CGSize(width: width, height: .greatestFiniteMagnitude)
        )
    }

    // Texture forwards this to its async delegate via `respondsToSelector:`
    // rather than declaring it in ASCollectionDelegate itself, so it must be
    // explicitly `@objc` to be picked up from Swift.
    @objc func scrollViewDidScroll(_ scrollView: UIScrollView) {
        backToTopButton.isHidden = scrollView.contentOffset.y <= Self.backToTopThreshold
    }
}

// MARK: - UISearchResultsUpdating

extension ClaimsListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        viewModel.search(searchController.searchBar.text ?? "")
    }
}
