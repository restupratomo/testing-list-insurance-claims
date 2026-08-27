import AsyncDisplayKit
import RxSwift

/// Claims list screen. Hosts an `ASCollectionNode` for cell-content prepared
/// off the main thread, a search bar for filtering, and a footer spinner for
/// pagination — all driven by `ClaimsListViewModel`'s Rx relays.
final class ClaimsListViewController: ASDKViewController<ASCollectionNode> {

    private let viewModel: ClaimsListViewModel
    private let collectionNode: ASCollectionNode
    private let searchController = UISearchController(searchResultsController: nil)
    private let activityIndicator = UIActivityIndicatorView(style: .gray)
    private let disposeBag = DisposeBag()

    init(viewModel: ClaimsListViewModel) {
        self.viewModel = viewModel

        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        self.collectionNode = ASCollectionNode(collectionViewLayout: layout)

        super.init(node: collectionNode)
        title = "Insurance Claims"
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

        configureSearchController()
        configureLoadingIndicator()
        bindViewModel()

        viewModel.loadFirstPage()
    }

    private func configureSearchController() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search claims"
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
        let alert = UIAlertController(title: "Unable to Load Claims", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Retry", style: .default, handler: { [weak self] _ in self?.retryTapped() }))
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
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
}

// MARK: - UISearchResultsUpdating

extension ClaimsListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        viewModel.search(searchController.searchBar.text ?? "")
    }
}
