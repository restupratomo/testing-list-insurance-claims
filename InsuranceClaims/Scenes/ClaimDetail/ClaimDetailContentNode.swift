import AsyncDisplayKit

/// Content of the claim detail screen: full title, full description and
/// identifiers. Kept as its own node (rather than a plain `ASDisplayNode`
/// configured with a `layoutSpecBlock`) so `automaticallyManagesSubnodes` is
/// set before the node's first layout pass, matching `ClaimCellNode`'s setup.
final class ClaimDetailContentNode: ASDisplayNode {
    private let titleNode = ASTextNode()
    private let descriptionNode = ASTextNode()
    private let metadataNode = ASTextNode()

    init(viewModel: ClaimDetailViewModel) {
        super.init()
        automaticallyManagesSubnodes = true
        // Without this, layoutSpecThatFits never accounts for the navigation
        // bar and the content renders underneath it instead of below it.
        automaticallyRelayoutOnSafeAreaChanges = true
        backgroundColor = .adaptiveBackground

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
    }

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        let stack = ASStackLayoutSpec(
            direction: .vertical,
            spacing: 12,
            justifyContent: .start,
            alignItems: .stretch,
            children: [titleNode, descriptionNode, metadataNode]
        )

        return ASInsetLayoutSpec(
            insets: UIEdgeInsets(
                top: safeAreaInsets.top + 20,
                left: 16,
                bottom: safeAreaInsets.bottom + 20,
                right: 16
            ),
            child: stack
        )
    }
}
