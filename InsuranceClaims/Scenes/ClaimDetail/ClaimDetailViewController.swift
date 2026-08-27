import AsyncDisplayKit

/// Full-detail screen for a single claim: title, complete description and
/// identifiers, laid out with Texture so it composes with the rest of the app.
final class ClaimDetailViewController: ASDKViewController<ASDisplayNode> {

    private let viewModel: ClaimDetailViewModel
    private let contentNode = ASDisplayNode()

    private let titleNode = ASTextNode()
    private let descriptionNode = ASTextNode()
    private let metadataNode = ASTextNode()

    init(viewModel: ClaimDetailViewModel) {
        self.viewModel = viewModel
        super.init(node: contentNode)
        title = viewModel.screenTitle
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        node.backgroundColor = .adaptiveBackground

        titleNode.attributedText = NSAttributedString(
            string: viewModel.title,
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .title2),
                .foregroundColor: UIColor.adaptiveLabel
            ]
        )

        descriptionNode.attributedText = NSAttributedString(
            string: viewModel.description,
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor.adaptiveLabel
            ]
        )

        metadataNode.attributedText = NSAttributedString(
            string: viewModel.metadata,
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .footnote),
                .foregroundColor: UIColor.adaptiveSecondaryLabel
            ]
        )

        contentNode.automaticallyManagesSubnodes = true
        contentNode.layoutSpecBlock = { [weak self] _, constrainedSize in
            guard let self = self else { return ASLayoutSpec() }
            let stack = ASStackLayoutSpec(
                direction: .vertical,
                spacing: 12,
                justifyContent: .start,
                alignItems: .stretch,
                children: [self.titleNode, self.descriptionNode, self.metadataNode]
            )
            return ASInsetLayoutSpec(
                insets: UIEdgeInsets(top: 20, left: 16, bottom: 20, right: 16),
                child: stack
            )
        }
    }
}
